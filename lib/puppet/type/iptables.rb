# Puppet Iptables Module
#
# Copyright (C) 2011 Bob.sh Limited
# Copyright (C) 2008 Camptocamp Association
# Copyright (C) 2007 Dmitri Priimak
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

require "ipaddr"
require 'resolv'
require 'puppet/util/iptables'
require 'puppet/util/ipcidr'

module Puppet

  # List of table names
  @@table_names = ['filter','nat','mangle','raw']

  # pre and post rules are loaded from files
  # pre.iptables post.iptables in /etc/puppet/iptables
  @@pre_file  = "/etc/puppet/iptables/pre.iptables"
  @@post_file = "/etc/puppet/iptables/post.iptables"

  # order in which the differents chains appear in iptables-save's output. Used
  # to sort the rules the same way iptables-save does.
  @@chain_order = {
    'PREROUTING'  => 1,
    'INPUT'       => 2,
    'FORWARD'     => 3,
    'OUTPUT'      => 4,
    'POSTROUTING' => 5,
  }    
      
  @@rules = {}

  @@current_rules = {}

  @@ordered_rules = {}

  @@total_rule_count = 0

  @@instance_count = 0

  @@finalized = false



  newtype(:iptables) do
    include Puppet::Util::Iptables

    @doc = "Manipulate iptables rules"

    newparam(:name) do
      desc "The name of the rule."
      isnamevar

      # Keep rule names simple
      validate do |value|
        if value !~ /^[a-zA-Z0-9 \-_]+$/ then
          self.fail "Not a valid rule name. Make sure it contains ASCII " \
            "alphanumeric, spaces, hyphens or underscoares." 
        end
      end
    end

    newparam(:chain) do
      desc "holds value of iptables -A parameter.
                  Possible values are: 'INPUT', 'FORWARD', 'OUTPUT', 'PREROUTING', 'POSTROUTING'.
                  Default value is 'INPUT'"
      newvalues(:INPUT, :FORWARD, :OUTPUT, :PREROUTING, :POSTROUTING)
      defaultto "INPUT"
    end

    newparam(:table) do
      desc "one of the following tables: 'nat', 'mangle',
                  'filter' and 'raw'. Default one is 'filter'"
      newvalues(:nat, :mangle, :filter, :raw)
      defaultto "filter"
    end

    newparam(:proto) do
      desc "holds value of iptables --protocol parameter.
                  Possible values are: 'tcp', 'udp', 'icmp', 'esp', 'ah', 'vrrp', 'igmp', 'all'.
                  Default value is 'tcp'"
      newvalues(:tcp, :udp, :icmp, :esp, :ah, :vrrp, :igmp, :all)
      defaultto "tcp"
    end

    newparam(:jump) do
      desc "holds value of iptables --jump target
                  Possible values are: 'ACCEPT', 'DROP', 'REJECT', 'DNAT', 'SNAT', 'LOG', 'MASQUERADE', 'REDIRECT'.
                  Default value is 'ACCEPT'. While this is not the accepted norm, this is the more commonly used jump target.
                  Users should ensure they do an explicit DROP for all packets after all the ACCEPT rules are specified."
      newvalues(:ACCEPT, :DROP, :REJECT, :DNAT, :SNAT, :LOG, :MASQUERADE, :REDIRECT)
      defaultto "ACCEPT"
    end

    newparam(:source) do
      desc "value for iptables --source parameter.
                  Accepts a single string or array."
    end

    newparam(:destination) do
      desc "value for iptables --destination parameter"
    end

    newparam(:sport) do
      desc "holds value of iptables [..] --source-port parameter.
                  If array is specified, values will be passed to multiport module.
                  Only applies to tcp/udp."
      defaultto ""
    end

    newparam(:dport) do
      desc "holds value of iptables [..] --destination-port parameter.
                  If array is specified, values will be passed to multiport module.
                  Only applies to tcp/udp."
      defaultto ""
    end

    newparam(:iniface) do
      desc "value for iptables --in-interface parameter"
    end

    newparam(:outiface) do
      desc "value for iptables --out-interface parameter"
    end

    newparam(:tosource) do
      desc "value for iptables '-j SNAT --to-source' parameter"
      defaultto ""
    end

    newparam(:todest) do
      desc "value for iptables '-j DNAT --to-destination' parameter"
      defaultto ""
    end

    newparam(:toports) do
      desc "value for iptables '-j REDIRECT --to-ports' parameter"
      defaultto ""
    end

    newparam(:reject) do
      desc "value for iptables '-j REJECT --reject-with' parameter"
      defaultto ""
    end

    newparam(:log_level) do
      desc "value for iptables '-j LOG --log-level' parameter"
      defaultto ""
    end

    newparam(:log_prefix) do
      desc "value for iptables '-j LOG --log-prefix' parameter"
      defaultto ""
    end

    newparam(:icmp) do
      desc "value for iptables '-p icmp --icmp-type' parameter"
      defaultto ""
    end

    newparam(:state) do
      desc "value for iptables '-m state --state' parameter.
                  Possible values are: 'INVALID', 'ESTABLISHED', 'NEW', 'RELATED'.
                  Also accepts an array of multiple values."
    end

    newparam(:limit) do
      desc "value for iptables '-m limit --limit' parameter.
                  Example values are: '50/sec', '40/min', '30/hour', '10/day'."
      defaultto ""
    end

    newparam(:burst) do
      desc "value for '--limit-burst' parameter.
                  Example values are: '5', '10'."
      defaultto ""
    end

    newparam(:redirect) do
      desc "value for iptables '-j REDIRECT --to-ports' parameter."
      defaultto ""
    end

    # Parse the output of iptables-save and return a hash with every parameter
    # of each rule
    def load_current_rules(numbered = false)
      ipt_save = Facter.value(:iptables_save_cmd)
      iptables_save_to_hash(`#{ipt_save}`, numbered)
    end

    # Load a file and using the passed in rules hash load the 
    # rules contained therein.
    def load_rules_from_file(rules, file_name, action)
      if File.exist?(file_name)
        counter = 0
        File.open(file_name, "r") do |infile|
          while (line = infile.gets)
            # Skip comments
            next unless /^\s*[^\s#]/.match(line.strip)

            # Get the table the rule is operating on
            table = line[/-t\s+\S+/]
            table = "-t filter" unless table
            table.sub!(/^-t\s+/, '')
            rules[table] = [] unless rules[table]

            # Build up rule hash
            rule =
              { 'table'   => table,
                'rule'    => line.strip}

            # Push or insert rule onto table entry in rules hash
            if( action == :prepend )
              rules[table].insert(counter, rule)
            else
              rules[table].push(rule)
            end

            counter += 1
          end
        end
      end
    end

    # finalize() gets run once every iptables resource has been declared.
    # It decides if puppet resources differ from currently active iptables
    # rules and applies the necessary changes.
    def finalize
      # sort rules by alphabetical order, grouped by chain, else they arrive in
      # random order and cause puppet to reload iptables rules.
      @@rules.each_key {|key|
        @@rules[key] = @@rules[key].sort_by { |rule| [rule["chain_prio"], rule["name"], rule["source"]] }
      }

      # load pre and post rules
      load_rules_from_file(@@rules, @@pre_file, :prepend)
      load_rules_from_file(@@rules, @@post_file, :append)

      # add numbered version to each rule
      @@table_names.each { |table|
        rules_to_set = @@rules[table]
        if rules_to_set
          counter = 1
          rules_to_set.each { |rule|
            rule['nrule'] = counter.to_s + " " + rule["rule"]
            counter += 1
          }
        end
      }

      # On the first round we delete rules which do not match what
      # we want to set. We have to do it in the loop until we
      # exhaust all rules, as some of them may appear as multiple times
      while self.delete_not_matched_rules > 0
      end

      # Now we need to take care of rules which are new or out of order.
      # The way we do it is that if we find any difference with the
      # current rules, we add all new ones and remove all old ones.
      if self.rules_are_different
        # load new new rules and benchmark the whole lot
        benchmark(:notice, self.noop ? "rules would have changed... (noop)" : "rules have changed...") do
          # load new rules
          @@table_names.each { |table|
            rules_to_set = @@rules[table]
            if rules_to_set
              rules_to_set.each { |rule_to_set|
                if self.noop
                  debug("Would have run [create]: 'iptables -t #{table} #{rule_to_set['rule']}' (noop)")
                  next
                else
                  ipt_cmd = Facter.value(:iptables_cmd)
                  debug("Running [create]: '#{ipt_cmd} -t #{table} #{rule_to_set['rule']}'")
                  `#{ipt_cmd} -t #{table} #{rule_to_set['rule']}`
                end
              }
            end
          }

          # delete old rules
          @@table_names.each { |table|
            current_table_rules = @@current_rules[table]
            if current_table_rules
              current_table_rules.each { |rule, data|
                if self.noop
                  debug("Would have run [delete]: 'iptables -t #{table} -D #{data['chain']} 1' (noop)")
                  next
                else
                  ipt_cmd = Facter.value(:iptables_cmd)
                  debug("Running [delete]: '#{ipt_cmd} -t #{table} -D #{data['chain']} 1'")
                  `#{ipt_cmd} -t #{table} -D #{data['chain']} 1`
                end
              }
            end
          }

          # Run iptables save to persist rules. The behaviour is to do nothing
          # if we know nothing of the operating system.
          persist_cmd = Facter.value(:iptables_persist_cmd)

          if persist_cmd != nil
            if Puppet[:noop]
              debug("Would have run [save]: #{persist_cmd} (noop)")
            else
              debug("Running [save]: #{persist_cmd}")
              system(persist_cmd)
            end
          else
            err("No save method known for your OS. Rules will not be saved!")
          end
        end

        @@rules = {}
      end

      @@finalized = true
    end

    def finalized?
      if defined? @@finalized
        return @@finalized
      else
        return false
      end
    end

    # Check if at least one rule found in iptables-save differs from what is
    # defined in puppet resources.
    def rules_are_different
      # load current rules
      @@current_rules = self.load_current_rules(true)

      @@table_names.each { |table|
        rules_to_set = @@rules[table]
        current_table_rules = @@current_rules[table]
        current_table_rules = {} unless current_table_rules
        current_table_rules.each do |rule, data|
          debug("Current tables rules: #{rule}")
        end
        if rules_to_set
          rules_to_set.each { |rule_to_set|
            debug("Looking for: #{rule_to_set['nrule']}")
            return true unless current_table_rules[rule_to_set['nrule']]
          }
        end
      }

      return false
    end

    def delete_not_matched_rules
      # load current rules
      @@current_rules = self.load_current_rules

      # count deleted rules from current active
      deleted = 0;

      # compare current rules with requested set
      @@table_names.each { |table|
        rules_to_set = @@rules[table]
        current_table_rules = @@current_rules[table]
        if rules_to_set
          if current_table_rules
            rules_to_set.each { |rule_to_set|
              rule = rule_to_set['rule']
              if current_table_rules[rule]
                current_table_rules[rule]['keep'] = 'me'
              end
            }
          end
        end

        # delete rules not marked with "keep" => "me"
        if current_table_rules
          current_table_rules.each { |rule, data|
            if data['keep']
            else
              if self.noop
                debug("Would have run [delete]: 'iptables -t #{table} #{rule.sub('-A', '-D')}' (noop)")
                next
              else
                ipt_cmd = Facter.value(:iptables_cmd)
                debug("Running [delete]: '#{ipt_cmd} -t #{table} #{rule.sub('-A', '-D')}'")
                `#{ipt_cmd} -t #{table} #{rule.sub("-A", "-D")}`
              end
              deleted += 1
            end
          }
        end
      }
      return deleted
    end

    def properties
      @@ordered_rules[self.name] = @@instance_count
      @@instance_count += 1

      if @@instance_count == @@total_rule_count
        self.finalize unless self.finalized?
      end
      return super
    end

    # Reset class variables to their initial value
    def self.clear
      @@rules = {}

      @@current_rules = {}

      @@ordered_rules = {}

      @@total_rule_count = 0

      @@instance_count = 0

      @@finalized = false
      super
    end


    def initialize(args)
      super(args)

      invalidrule = false
      @@total_rule_count += 1

      table = value(:table).to_s
      @@rules[table] = [] unless @@rules[table]

      # Create a Hash with all available params defaulted to empty strings.
      strings = self.class.allattrs.inject({}) { |x,y| x[y] = ""; x }

      if value(:table).to_s == "filter" and ["PREROUTING", "POSTROUTING"].include?(value(:chain).to_s)
        invalidrule = true
        err("PREROUTING and POSTROUTING cannot be used in table 'filter'. Ignoring rule.")
      elsif  value(:table).to_s == "nat" and ["INPUT", "FORWARD"].include?(value(:chain).to_s)
        invalidrule = true
        err("INPUT and FORWARD cannot be used in table 'nat'. Ignoring rule.")
      elsif  value(:table).to_s == "raw" and ["INPUT", "FORWARD", "POSTROUTING"].include?(value(:chain).to_s)
        invalidrule = true
        err("INPUT, FORWARD and POSTROUTING cannot be used in table 'raw'. Ignoring rule.")
      else
        strings[:table] = "-A " + value(:chain).to_s
      end

      sources = []
      if value(:source).to_s != ""
        value(:source).each { |source|
          if source !~ /\//
            source = Resolv.getaddress(source)
          end
          ip = Puppet::Util::IpCidr.new(source.to_s)
          if Facter.value("iptables_ipcidr")
            source = ip.cidr
          else
            source = ip.to_s
            source += sprintf("/%s", ip.netmask) unless ip.prefixlen == 32
          end
          sources.push({
            :host   => source,
            :string => " -s " + source
          })
        }
      else
        # Used later for a single iteration of the rule if there are no sources.
        sources.push({
          :host   => "",
          :string => ""
        })
      end

      destination = value(:destination).to_s
      if destination != ""
        if destination !~ /\//
          destination = Resolv.getaddress(destination)
        end
        ip = Puppet::Util::IpCidr.new(destination)
        if Facter.value("iptables_ipcidr")
          destination = ip.cidr
        else
          destination = ip.to_s
          destination += sprintf("/%s", ip.netmask) unless ip.prefixlen == 32
        end
        strings[:destination] = " -d " + destination
      end

      if value(:iniface).to_s != ""
        if ["INPUT", "FORWARD", "PREROUTING"].include?(value(:chain).to_s)
          strings[:iniface] = " -i " + value(:iniface).to_s
        else
          invalidrule = true
          err("--in-interface only applies to INPUT/FORWARD/PREROUTING. Ignoring rule.")
        end
      end

      if value(:outiface).to_s != ""
        if ["OUTPUT", "FORWARD", "POSTROUTING"].include?(value(:chain).to_s)
          strings[:outiface] = " -o " + value(:outiface).to_s
        else
          invalidrule = true
          err("--out-interface only applies to OUTPUT/FORWARD/POSTROUTING. Ignoring rule.")
        end
      end

      if value(:proto).to_s != "all"
        strings[:proto] = " -p " + value(:proto).to_s
        if not ["vrrp", "igmp"].include?(value(:proto).to_s)
          strings[:proto] += " -m " + value(:proto).to_s
        end
      end

      if value(:dport).to_s != ""
        if ["tcp", "udp"].include?(value(:proto).to_s)
          if value(:dport).is_a?(Array)
            if value(:dport).length <= 15
              strings[:dport] = " -m multiport --dports " + value(:dport).join(",")
            else
              invalidrule = true
              err("multiport module only accepts <= 15 ports. Ignoring rule.")
            end
          else
            strings[:dport] = " --dport " + value(:dport).to_s
          end
        else
          invalidrule = true
          err("--destination-port only applies to tcp/udp. Ignoring rule.")
        end
      end

      if value(:sport).to_s != ""
        if ["tcp", "udp"].include?(value(:proto).to_s)
          if value(:sport).is_a?(Array)
            if value(:sport).length <= 15
              strings[:sport] = " -m multiport --sports " + value(:sport).join(",")
            else
              invalidrule = true
              err("multiport module only accepts <= 15 ports. Ignoring rule.")
            end
          else
            strings[:sport] = " --sport " + value(:sport).to_s
          end
        else
          invalidrule = true
          err("--source-port only applies to tcp/udp. Ignoring rule.")
        end
      end

      value_icmp = ""
      if value(:proto).to_s == "icmp"
        if value(:icmp).to_s == ""
          value_icmp = "any"
        else
          # Translate the symbolic names for icmp packet types to
          # numbers. Otherwise iptables-save saves the rules as numbers
          # and we will always fail the comparison causing re-loads.
          value_icmp = icmp_name_to_number(value(:icmp).to_s)

          if value_icmp == nil
            invalidrule = true
            err("Value for 'icmp' is invalid/unknown. Ignoring rule.")
          end

        end

        strings[:icmp] = " --icmp-type " + value_icmp
      end

      # let's specify the order of the states as iptables uses them
      state_order = ["INVALID", "NEW", "RELATED", "ESTABLISHED"]
      if value(:state).is_a?(Array)

        invalid_state = false
        value(:state).each {|v|
          invalid_state = true unless state_order.include?(v)
        }

        if value(:state).length <= state_order.length and not invalid_state

          # return only the elements that appear in both arrays.
          # This filters out bad entries (unfortunately silently), and orders the entries
          # in the same order as the 'state_order' array
          states = state_order & value(:state)

          strings[:state] = " -m state --state " + states.join(",")
        else
          invalidrule = true
          err("'state' accepts any the following states: #{state_order.join(", ")}. Ignoring rule.")
        end
      elsif value(:state).to_s != ""
        if state_order.include?(value(:state).to_s)
          strings[:state] = " -m state --state " + value(:state).to_s
        else
          invalidrule = true
          err("'state' accepts any the following states: #{state_order.join(", ")}. Ignoring rule.")
        end
      end

      if value(:name).to_s != ""
        strings[:comment] = " -m comment --comment \"" + value(:name).to_s + "\""
      end

      if value(:limit).to_s != ""
        limit_value = value(:limit).to_s
        if not limit_value.include? "/"
          invalidrule = true
          err("Please append a valid suffix (sec/min/hour/day) to the value passed to 'limit'. Ignoring rule.")
        else
          limit_value = limit_value.split("/")
          if limit_value[0] !~ /^[0-9]+$/
            invalidrule = true
            err("'limit' values must be numeric. Ignoring rule.")
          elsif ["sec", "min", "hour", "day"].include? limit_value[1]
            strings[:limit] = " -m limit --limit " + value(:limit).to_s
          else
            invalidrule = true
            err("Please use only sec/min/hour/day suffixes with 'limit'. Ignoring rule.")
          end
        end
      end

      if value(:burst).to_s != ""
        if value(:limit).to_s == ""
          invalidrule = true
          err("'burst' makes no sense without 'limit'. Ignoring rule.")
        elsif value(:burst).to_s !~ /^[0-9]+$/
          invalidrule = true
          err("'burst' accepts only numeric values. Ignoring rule.")
        else
          strings[:burst] = " --limit-burst " + value(:burst).to_s
        end
      end

      strings[:jump] = " -j " + value(:jump).to_s

      value_reject = ""
      if value(:jump).to_s == "DNAT"
        if value(:table).to_s != "nat"
          invalidrule = true
          err("DNAT only applies to table 'nat'.")
        elsif value(:todest).to_s == ""
          invalidrule = true
          err("DNAT missing mandatory 'todest' parameter.")
        else
          strings[:todest] = " --to-destination " + value(:todest).to_s
        end
      elsif value(:jump).to_s == "SNAT"
        if value(:table).to_s != "nat"
          invalidrule = true
          err("SNAT only applies to table 'nat'.")
        elsif value(:tosource).to_s == ""
          invalidrule = true
          err("SNAT missing mandatory 'tosource' parameter.")
        else
          strings[:tosource] = " --to-source " + value(:tosource).to_s
        end
      elsif value(:jump).to_s == "REDIRECT"
        if value(:toports).to_s == ""
          invalidrule = true
          err("REDIRECT missing mandatory 'toports' parameter.")
        else
          strings[:toports] = " --to-ports " + value(:toports).to_s
        end
      elsif value(:jump).to_s == "REJECT"
        # Apply the default rejection type if none is specified.
        value_reject = value(:reject).to_s != "" ? value(:reject).to_s : "icmp-port-unreachable"
        strings[:reject] = " --reject-with " + value_reject
      elsif value(:jump).to_s == "LOG"
        if value(:log_level).to_s != ""
          strings[:log_level] = " --log-level " + value(:log_level).to_s
        end
        if value(:log_prefix).to_s != ""
          # --log-prefix has a 29 characters limitation.
          log_prefix = "\"" + value(:log_prefix).to_s[0,27] + ": \""
          strings[:log_prefix] = " --log-prefix " + log_prefix
        end
      elsif value(:jump).to_s == "MASQUERADE"
        if value(:table).to_s != "nat"
          invalidrule = true
          err("MASQUERADE only applies to table 'nat'.")
        end
      elsif value(:jump).to_s == "REDIRECT"
        if value(:redirect).to_s != ""
          strings[:redirect] = " --to-ports " + value(:redirect).to_s
        end
      end

      chain_prio = @@chain_order[value(:chain).to_s]

      # Generate a rule entry for each source permutation.
      sources.each { |source|
        
        # Build a string of arguments in the required order.
        rule_string = "%s" * 21 % [
          strings[:table],
          source[:string],
          strings[:destination],
          strings[:iniface],
          strings[:outiface],
          strings[:proto],
          strings[:sport],
          strings[:dport],
          strings[:icmp],
          strings[:state],
          strings[:comment],
          strings[:limit],
          strings[:burst],
          strings[:jump],
          strings[:todest],
          strings[:tosource],
          strings[:toports],
          strings[:reject],
          strings[:log_level],
          strings[:log_prefix],
          strings[:redirect]
        ]
        
        debug("iptables param: #{rule_string}")
        if invalidrule != true
          @@rules[table].push({
            'name'          => value(:name).to_s,
            'chain'         => value(:chain).to_s,
            'table'         => value(:table).to_s,
            'proto'         => value(:proto).to_s,
            'jump'          => value(:jump).to_s,
            'source'        => source[:host],
            'destination'   => value(:destination).to_s,
            'sport'         => value(:sport).to_s,
            'dport'         => value(:dport).to_s,
            'iniface'       => value(:iniface).to_s,
            'outiface'      => value(:outiface).to_s,
            'todest'        => value(:todest).to_s,
            'tosource'      => value(:tosource).to_s,
            'toports'       => value(:toports).to_s,
            'reject'        => value_reject,
            'redirect'      => value(:redirect).to_s,
            'log_level'     => value(:log_level).to_s,
            'log_prefix'    => value(:log_prefix).to_s,
            'icmp'          => value_icmp,
            'state'         => value(:state).to_s,
            'limit'         => value(:limit).to_s,
            'burst'         => value(:burst).to_s,
            'chain_prio'    => chain_prio.to_s,
            'rule'          => rule_string
          })
        end
      }
    end
  end
end