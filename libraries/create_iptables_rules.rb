#
# Cookbook Name:: iptables-ng
# Recipe:: manage
#
# Copyright 2013, Chris Aumann
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# This was implemented as a internal-only provider.
# Apparently, calling a LWRP from a LWRP doesnt' really work with
# subscribes / notifies. Therefore, using this workaround.

module Iptables
  module Manage
    def create_iptables_rules(ip_version)
      rules = {}

      # Retrieve all iptables rules for this ip_version,
      # as well as default policies
      Dir["#{node['iptables-ng']['scratch_dir']}/*/*/*.rule_v#{ip_version}",
          "#{node['iptables-ng']['scratch_dir']}/*/*/default"].each do |path|

        # #{node['iptables-ng']['scratch_dir']}/#{table}/#{chain}/#{rule}.rule_v#{ip_version}
        path.slice! "#{node['iptables-ng']['scratch_dir']}"
        table, chain, filename = path.split('/')[1..3]
        rule = ::File.basename(filename)

        # ipv6 doesn't support nat
        next if table == 'nat' && ip_version == 6

        # Skip deactivated tables
        next unless node['iptables-ng']['enabled_tables'].include?(table)

        # Create hashes unless they already exist, and add the rule
        rules[table] ||= {}
        rules[table][chain] ||= {}
        rules[table][chain][rule] = ::File.read("#{node['iptables-ng']['scratch_dir']}/#{path}")
      end

      iptables_restore = ''
      rules.each do |table, chains|
        iptables_restore << "*#{table}\n"

        # Get default policies and rules for this chain
        default_policies = chains.each_with_object({}) do |rule, new_chain|
          new_chain[rule[0]] = rule[1].select { |k, _| k == 'default' }
        end

        all_chain_rules  = chains.each_with_object({}) do |rule, new_chain|
          new_chain[rule[0]] = rule[1].reject { |k, _| k == 'default' }
        end

        # Apply default policies first
        default_policies.each do |chain, policy|
          iptables_restore << ":#{chain} #{policy['default'].chomp}\n"
        end

        # Apply rules for this chain, but sort before adding
        all_chain_rules.each do |_chain, chain_rules|
          chain_rules.sort.each { |r| iptables_restore << "#{r.last.chomp}\n" }
        end

        iptables_restore << "COMMIT\n"
      end

      Chef::Resource::File.new(node['iptables-ng']["script_ipv#{ip_version}"], run_context).tap do |file|
        file.owner('root')
        file.group(node['root_group'])
        file.mode(00600)
        file.content(iptables_restore)
        file.run_action(:create)
      end
    end
  end
end
