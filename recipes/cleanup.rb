#
# Cookbook Name:: sidekiq
# Recipe:: cleanup
#

# reload monit
execute "reload-monit" do
  command "monit quit && telinit q"
  action :nothing
end

node[:sidekiq].each_with_index do | sidekiq, idx |
  unless util_or_app_server?(sidekiq[:utility_name])
    # report to dashboard
    ey_cloud_report "sidekiq" do
      message "Cleaning up sidekiq #{idx} (if needed)"
    end

    if app_server? || util?
      # loop through applications
      node[:applications].each do |app_name, _|
        # monit
        file "/etc/monit.d/sidekiq_#{idx}_#{app_name}.monitrc" do
          action :delete
          notifies :run, resources(:execute => "reload-monit")
        end

        # yml files
        sidekiq[:workers].times do |count|
          file "/data/#{app_name}/shared/config/sidekiq_#{idx}_#{count}.yml" do
            action :delete
          end
        end
      end

      # bin script
      file "/engineyard/bin/sidekiq" do
        action :delete
      end

      # stop sidekiq
      execute "kill-sidekiq" do
        command "pkill -f sidekiq"
        only_if "pgrep -f sidekiq"
      end
    end
  end
end
