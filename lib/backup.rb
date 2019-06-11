require "json"
require_relative "time_elapsed"

class Backup < Struct.new(:options)
  include TimeElapsed

  def run
    @now = Time.now.to_i
    puts "\e[H\e[2J"

    label_volumes

    backup_command = "velero schedule create #{options[:backup]} --include-namespaces #{included_namespaces.join(",")} --exclude-resources=orders.certmanager.k8s.io,challenges.certmanager.k8s.io --snapshot-volumes --volume-snapshot-locations=default"
    backup_command << " --schedule='#{options[:schedule]}'" unless options[:schedule]

    puts "Backup in progress...." unless options[:schedule]

    `#{backup_command}`

    if options[:schedule]
      backup_name = `kubectl -n velero get backup --selector 'velero.io/schedule-name=#{options[:backup]}' --sort-by=.status.completionTimestamp -o jsonpath='{.items[*].metadata.name}'`.split.first
      puts "Backup scheduled and started. Run `velero describe backup #{backup_name} --details` for progress about the current backup."
    else
      elapsed = Time.now.to_i - @now
      puts "\n\nBackup completed in #{humanize elapsed}"
    end
  end

  private

  def included_namespaces
    options[:included_namespaces]
  end

  def label_volumes
    JSON.parse(`kubectl get pvc --all-namespaces -o json`)["items"].select do |pvc|
      namespace = pvc["metadata"]["namespace"]

      if included_namespaces.include? namespace
        pv = pvc["spec"]["volumeName"]
        `kubectl label pv #{pv} openebs.io/namespace=#{namespace} --overwrite`
      end
    end
  end
end
