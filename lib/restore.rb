require 'date'
require 'json'
require_relative "time_elapsed"

class Restore < Struct.new(:options)
  include TimeElapsed

  def run
    @now = Time.now.to_i
    puts "\e[H\e[2J"

    puts "(Temp. hack) Cleaning up zombie zfs volumes..."
    `#{File.join(File.expand_path("..", File.dirname(__FILE__)), "zfs-cleanup.sh")}`

    if existing_namespaces.any?
      puts "WARNING: The namespaces [#{existing_namespaces.join(", ")}] already exist. Make sure none of the namespaces to restore already exist."
      exit
    end

    puts "Creating namespaces to restore..."

    included_namespaces.each { |ns| `kubectl create ns #{ns}` }

    puts "*** Restoring one full backup #{ ('and ' + (backups.size - 1).to_s + ' incrementals ') if backups.size > 1 }***\n\n "

    backups.each do |backup|
      puts "Restoring #{backup}...\n"
      `velero restore create --from-backup #{backup} --include-namespaces #{included_namespaces.join(",")} --selector \"openebs.io/namespace notin (#{excluded_namespaces.join(",")})\" --restore-volumes=true --wait`
      break if backup == options[:backup]
    end

    set_target_ip

    elapsed = Time.now.to_i - @now
    puts "\n\nRestore completed in #{humanize elapsed}"
  end

  private

  def all_backups_in_schedule
    @all_backups_in_schedule ||= `kubectl -n velero get backup --selector 'velero.io/schedule-name=#{schedule_name}' --sort-by=.status.completionTimestamp -o jsonpath='{.items[*].metadata.name}'`.split
  end

  def pvs_by_backup
    return @pvs_by_backup if @pvs_by_backup

    @pvs_by_backup = {}

    all_backups_in_schedule.each do |backup|
      backup_details = `velero describe backup #{backup} --details`
      @pvs_by_backup[backup] = backup_details.match(/\nPersistent\sVolumes:\n(.*)/m)[1].scan(/(pvc-.*):/).to_a.flatten
      break if backup == options[:backup]
    end

    @pvs_by_backup
  end

  def backups_in_schedule
    selected_backups = [options[:backup]]

    return selected_backups if pvs_by_backup.keys.length == 1

    i = pvs_by_backup.keys.length - 2

    while i >= 0
      common_pvs = (pvs_by_backup[pvs_by_backup.keys[i]] & pvs_by_backup[pvs_by_backup.keys[i+1]])
      break if common_pvs.empty?
      selected_backups << pvs_by_backup.keys[i]
      i -= 1
    end

    selected_backups.reverse
  end

  def schedule_name
    @schedule_name ||= `kubectl -n velero get backup #{options[:backup]} -o jsonpath='{.metadata.labels.velero\\.io/schedule-name}'`
  end

  def scheduled?
    ! schedule_name.empty?
  end

  def backups
    @backups ||= if scheduled?
      backups_in_schedule
    else
      [options[:backup]]
    end
  end

  def included_namespaces
    options[:included_namespaces]
  end

  def excluded_namespaces
    all_namespaces = JSON.parse(`kubectl -n velero get backup #{backups.first} -o json`).dig("spec", "includedNamespaces")
    all_namespaces - included_namespaces
  end

  def existing_namespaces
    included_namespaces & `kubectl get ns -o jsonpath='{.items[*].metadata.name}'`.split
  end

  def set_target_ip
    pod_name = `kubectl -n openebs get pod -l app=cstor-pool -o jsonpath='{.items[0].metadata.name}'`
    pool_name = `kubectl -n openebs exec -it #{pod_name} -c cstor-pool -- zpool list -Ho name`.chop

    restored_pvs = JSON.parse(`kubectl get pvc --all-namespaces -o json`)["items"].select do |pvc|
      included_namespaces.include? pvc["metadata"]["namespace"]
    end.map do |pvc|
      pvc["spec"]["volumeName"]
    end

    restored_pvs.each do |pv|
      target_ip = `kubectl get pv #{pv} -o jsonpath='{.spec.iscsi.targetPortal}'`.split(":").first
      target_name="#{pool_name}/#{pv}"

      `kubectl -n openebs exec -it #{pod_name} -c cstor-pool -- zfs set io.openebs:targetip=#{target_ip} #{target_name}`
    end
  end
end
