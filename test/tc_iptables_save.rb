#!/usr/bin/env ruby

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

require 'test/unit'
require 'puppet/util/iptables'
require 'pp'

class TestIPTablesSave < Test::Unit::TestCase
  include Puppet::Util::Iptables
  
  def test_iptables_save_hash_1
    
    input = <<EOT
# Generated by iptables-save v1.4.10 on Thu Mar 10 22:52:05 2011
*mangle
:PREROUTING ACCEPT [875664:689439240]
:INPUT ACCEPT [873529:689050567]
:FORWARD ACCEPT [112:51887]
:OUTPUT ACCEPT [916757:232100143]
:POSTROUTING ACCEPT [916911:232159718]
COMMIT
# Completed on Thu Mar 10 22:52:05 2011
# Generated by iptables-save v1.4.10 on Thu Mar 10 22:52:05 2011
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [18:2900]
:OUTPUT ACCEPT [916757:232100143]
-A INPUT -p icmp -m icmp --icmp-type any -m comment --comment "Accept all icmp" -j ACCEPT 
-A INPUT -i lo -m comment --comment "Accept all to lo interface" -j ACCEPT 
-A INPUT -i br1 -p tcp -m tcp --dport 53 -m comment --comment "Allow DNS access from virtuals - tcp" -j ACCEPT 
-A INPUT -i br1 -p udp -m udp --dport 53 -m comment --comment "Allow DNS access from virtuals - udp" -j ACCEPT 
-A INPUT -p tcp -m tcp -m multiport --dports 22,8001 -m comment --comment "Allow SSH from everywhere" -j ACCEPT 
-A INPUT -m state --state RELATED,ESTABLISHED -m comment --comment "Default input REL,EST" -j ACCEPT 
-A INPUT -j DROP 
-A FORWARD -i br1 -o br1 -p tcp -m tcp -m comment --comment "100_Forward between virts" -j ACCEPT 
-A FORWARD -s 10.22.100.0/24 -i br1 -p tcp -m tcp -m comment --comment "100_Forward from virts" -j ACCEPT 
-A FORWARD -d 10.22.100.0/24 -o br1 -p tcp -m tcp -m state --state RELATED,ESTABLISHED -m comment --comment "100_Forward to virts" -j ACCEPT 
-A FORWARD -i br0 -p tcp -m tcp -m comment --comment "900_Reject forwards from virts" -j REJECT --reject-with icmp-port-unreachable 
-A FORWARD -o br0 -p tcp -m tcp -m comment --comment "900_Reject forwards to virts" -j REJECT --reject-with icmp-port-unreachable 
COMMIT
# Completed on Thu Mar 10 22:52:05 2011
# Generated by iptables-save v1.4.10 on Thu Mar 10 22:52:05 2011
*nat
:PREROUTING ACCEPT [7135:1080650]
:POSTROUTING ACCEPT [43615:3110171]
:OUTPUT ACCEPT [43613:3109869]
-A POSTROUTING -s 10.22.100.0/24 -o br0 -p tcp -m tcp -m comment --comment "100_Masquerade other ips - tcp" -j MASQUERADE 
-A POSTROUTING -s 10.22.100.0/24 -o br0 -p udp -m udp -m comment --comment "100_Masquerade other ips - udp" -j MASQUERADE 
-A POSTROUTING -s 10.22.100.0/24 -o br0 -m comment --comment "101_Masquerade other ips - other protos" -j MASQUERADE 
COMMIT
# Completed on Thu Mar 10 22:52:05 2011
EOT
    
    hash = 
      {"nat"=>
        {"-A POSTROUTING -s 10.22.100.0/24 -o br0 -p udp -m udp -m comment --comment \"100_Masquerade other ips - udp\" -j MASQUERADE"=>
          {"name"=>"\"100_Masquerade",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"MASQUERADE",
           "tosource"=>"",
           "outiface"=>"br0",
           "destination"=>nil,
           "chain"=>"POSTROUTING",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"",
           "table"=>"nat",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>"10.22.100.0/255.255.255.0",
           "state"=>"",
           "proto"=>"udp"},
         "-A POSTROUTING -s 10.22.100.0/24 -o br0 -p tcp -m tcp -m comment --comment \"100_Masquerade other ips - tcp\" -j MASQUERADE"=>
          {"name"=>"\"100_Masquerade",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"MASQUERADE",
           "tosource"=>"",
           "outiface"=>"br0",
           "destination"=>nil,
           "chain"=>"POSTROUTING",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"",
           "table"=>"nat",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>"10.22.100.0/255.255.255.0",
           "state"=>"",
           "proto"=>"tcp"},
         "-A POSTROUTING -s 10.22.100.0/24 -o br0 -m comment --comment \"101_Masquerade other ips - other protos\" -j MASQUERADE"=>
          {"name"=>"\"101_Masquerade",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"MASQUERADE",
           "tosource"=>"",
           "outiface"=>"br0",
           "destination"=>nil,
           "chain"=>"POSTROUTING",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"",
           "table"=>"nat",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>"10.22.100.0/255.255.255.0",
           "state"=>"",
           "proto"=>"all"}},
        "filter"=>
        {"-A INPUT -i br1 -p udp -m udp --dport 53 -m comment --comment \"Allow DNS access from virtuals - udp\" -j ACCEPT"=>
          {"name"=>"\"Allow",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"INPUT",
           "toports"=>"",
           "iniface"=>"br1",
           "dport"=>"53",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"udp"},
         "-A INPUT -i br1 -p tcp -m tcp --dport 53 -m comment --comment \"Allow DNS access from virtuals - tcp\" -j ACCEPT"=>
          {"name"=>"\"Allow",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"INPUT",
           "toports"=>"",
           "iniface"=>"br1",
           "dport"=>"53",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"tcp"},
         "-A INPUT -i lo -m comment --comment \"Accept all to lo interface\" -j ACCEPT"=>
          {"name"=>"\"Accept",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"INPUT",
           "toports"=>"",
           "iniface"=>"lo",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"all"},
         "-A INPUT -m state --state RELATED,ESTABLISHED -m comment --comment \"Default input REL,EST\" -j ACCEPT"=>
          {"name"=>"\"Default",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"INPUT",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"RELATED,ESTABLISHED",
           "proto"=>"all"},
         "-A FORWARD -d 10.22.100.0/24 -o br1 -p tcp -m tcp -m state --state RELATED,ESTABLISHED -m comment --comment \"100_Forward to virts\" -j ACCEPT"=>
          {"name"=>"\"100_Forward",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"br1",
           "destination"=>"10.22.100.0/255.255.255.0",
           "chain"=>"FORWARD",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"RELATED,ESTABLISHED",
           "proto"=>"tcp"},
         "-A INPUT -p icmp -m icmp --icmp-type any -m comment --comment \"Accept all icmp\" -j ACCEPT"=>
          {"name"=>"\"Accept",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"INPUT",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"any",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"icmp"},
         "-A FORWARD -i br0 -p tcp -m tcp -m comment --comment \"900_Reject forwards from virts\" -j REJECT --reject-with icmp-port-unreachable"=>
          {"name"=>"\"900_Reject",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"REJECT",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"FORWARD",
           "toports"=>"",
           "iniface"=>"br0",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"icmp-port-unreachable",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"tcp"},
         "-A INPUT -p tcp -m tcp -m multiport --dports 22,8001 -m comment --comment \"Allow SSH from everywhere\" -j ACCEPT"=>
          {"name"=>"\"Allow",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"INPUT",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"22,8001",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"tcp"},
         "-A FORWARD -i br1 -o br1 -p tcp -m tcp -m comment --comment \"100_Forward between virts\" -j ACCEPT"=>
          {"name"=>"\"100_Forward",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"br1",
           "destination"=>nil,
           "chain"=>"FORWARD",
           "toports"=>"",
           "iniface"=>"br1",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"tcp"},
         "-A INPUT -j DROP"=>
          {"name"=>nil,
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"DROP",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"INPUT",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"all"},
         "-A FORWARD -o br0 -p tcp -m tcp -m comment --comment \"900_Reject forwards to virts\" -j REJECT --reject-with icmp-port-unreachable"=>
          {"name"=>"\"900_Reject",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"REJECT",
           "tosource"=>"",
           "outiface"=>"br0",
           "destination"=>nil,
           "chain"=>"FORWARD",
           "toports"=>"",
           "iniface"=>"",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"icmp-port-unreachable",
           "sport"=>"",
           "source"=>nil,
           "state"=>"",
           "proto"=>"tcp"},
         "-A FORWARD -s 10.22.100.0/24 -i br1 -p tcp -m tcp -m comment --comment \"100_Forward from virts\" -j ACCEPT"=>
          {"name"=>"\"100_Forward",
           "log_level"=>"",
           "todest"=>"",
           "jump"=>"ACCEPT",
           "tosource"=>"",
           "outiface"=>"",
           "destination"=>nil,
           "chain"=>"FORWARD",
           "toports"=>"",
           "iniface"=>"br1",
           "dport"=>"",
           "table"=>"filter",
           "log_prefix"=>"",
           "redirect"=>"",
           "burst"=>"",
           "limit"=>"",
           "icmp"=>"",
           "reject"=>"",
           "sport"=>"",
           "source"=>"10.22.100.0/255.255.255.0",
           "state"=>"",
           "proto"=>"tcp"}},
        "mangle"=>{}}

    assert_equal(hash, iptables_save_to_hash(input))
  end
end
