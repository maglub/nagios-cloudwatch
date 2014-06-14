#!/usr/bin/ruby
#============================================
# Script: check_ec2_meta_moniotor
# Author: Magnus Luebeck, magnus.luebeck@kmggroup.ch
# Date:   2014-05-19
#
# Description: This script will list instances in AWS and their 
#              current monitoring status
#
# Copyright 2014 KMG Group GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.
#
# Note: A lot of this plugin has been inspired by check_cloudwatch_status.rb from SecludIT, which
#       can be downloaded from:
#       http://exchange.nagios.org/directory/Plugins/Operating-Systems/*-Virtual-Environments/Others/Check_AWS_CloudWatch_metrics/details
#============================================

%w[ rubygems getoptlong yaml aws-sdk pp ].each { |f| require f }
$stdout.sync = true

#============================================
# Predefined variables 
#============================================
AWS_NAMESPACE_EC2 = "AWS/EC2"
AWS_NAMESPACE_RDS = "AWS/RBS"
AWS_NAMESPACE_ELB = "AWS/ELB"

AWS_METRIC_ELB = "HealthyHostCount" #Default metric


#--- Reference for API Class: AWS::CloudWatch::Metric
#---  http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/CloudWatch/Metric.html#statistics-instance_method
#--- Reference for API Class AWS::CloudWatch::Client
#--- http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/CloudWatch/Client.html

#--- Reference for AWS Cloudwatch Namespaces, Dimensions, and Metrics
#---  http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/CW_Support_For_AWS.html


#--- Available metrics for ELB -> http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/elb-metricscollected.html
#---     BackendConnectionErrors  -> Use --statistics
#---     HealthyHostCount
#---     HTTPCode_Backend_2XX
#---     HTTPCode_Backend_3XX
#---     HTTPCode_Backend_4XX
#---     HTTPCode_ELB_5XX
#---     Latency
#---     RequestCount
#---     UnHealthyHostCount

#--- Default metrics for EC2 -> http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/ec2-metricscollected.html
#---     StatusCheckFailed_Instance
#---     StatusCheckFailed
#---     DiskWriteBytes
#---     NetworkIn
#---     NetworkOut
#---     CPUUtilization
#---     DiskWriteOps
#---     DiskReadOps
#---     DiskReadBytes
#---     StatusCheckFailed_System


AWS_STATISTICS  = ["Average","Minimum","Maximum", "Sum"]
AWS_STATISTICS_WINDOW = 300                    # in seconds
AWS_STATISTICS_PERIOD = AWS_STATISTICS_WINDOW  # in seconds (since we are not plotting anything, we only need one value)

NAGIOS_CODE_OK        = {:value => 0, :msg => "OK" }
NAGIOS_CODE_WARNING   = {:value => 1, :msg => "WARNING" }
NAGIOS_CODE_CRITICAL  = {:value => 2, :msg => "CRITICAL" }
NAGIOS_CODE_UNKNOWN   = {:value => 3, :msg => "UNKNOWN" }

#--- the config file will be looked for in the same directory as this script
#--- Use -C to point to another directory
configDir   = File.expand_path(File.dirname(__FILE__) )
configFile  = File.expand_path(configDir + '/config.yml')

regionOverride    = nil
accessKeyOverride = nil
secretKeyOverride = nil
noMonitoringTag   = nil
                     
instance_id       = nil

namespace         = AWS_NAMESPACE_ELB
metric            = AWS_METRIC_ELB
statistics        = AWS_STATISTICS
statisticsWindow  = AWS_STATISTICS_WINDOW
statisticsPeriod  = AWS_STATISTICS_PERIOD
optPeriod         = nil
optWindow         = nil

thresholdCritical = nil
thresholdWarning  = nil
optListMetrics    = false

$debug    = false
$verbose  = false

#============================================
# Functions
#============================================
def usage
  puts <<EOT
Usage: #{$0} [-v]
  --help, -h:                              This Help
  --config, -C:                            Use config file (default ../etc/config.yml)
  --region=region, -r region:              Connect to region (i.e us-west-1, us-west-2)
  --access_key=ACCESS_KEY, -A ACCESS_KEY:  Use access key
  --secret_key=ACCESS_KEY, -S ACCESS_KEY:      Use secret access key
  --instance, -i:                          Instance id or Load balancer name
  --list-metrics                           List available metrics (should be used together with -i)
  --metric=<metric>                        Metric to report
  --namespace=<namespace>                  Set the namespace
  --window=<seconds>:                      Time in seconds for the number of seconds back in time to fetch statistics
  --period=<seconds>:                      Time in seconds for the bin-size of the statistics (multiple of 60 seconds, but for practical reasons should be the same as --window)
  --statistics:                            Statistics to gather, default "Average,Minimum,Maximum". Can also include Sum and Count
  --verbose,-v:                            Show some more output on stderr on what is going on
  --debug:                                 Show a lot more output on stderr on what is going on
  
  Thresholds:
  
  --warning={@}<threshold>{+}, -w {@}<threshold>{+}
  --critical={@}<threshold>{+}, -c {@}<threshold>{+}

  The threshold can be a single value or a range and can be decimal values. A threshold can be checked to be within a range or outside a range.
  To alert when a value is outside a range, use the prefix "@". The values can be checked with "hard" (default) or "soft" precision (by suffixiing
  the threshold with a "+"). Valid thresholds are:
  
  1, 1.0, 1:+, :1.5, 0:1000, @1:100
  
  "-c 75"    will trigger when the value is equal to or larger than 75
  "-c 75+"   will trigger when the value is larger than 75
  "-c 0:1"   will trigger when the value is equal to or larger than 0 and equal to or less than 1 
  "-c 0:1+"  will trigger when the value is larger than 0 and less than 1
Example:

* The authentication and settings in ../etc/config.yml are used, but region is us-west-2

  #{$0} --region=us-west-2

* Use another config file than default (config.yml)

  #{$0} --config=/path/to/my/config/file.yml
  
Critical and Warning thresholds

The warning and critical thresholds are defined as ranges, where an alert will be triggerd depending of whether the checked value is 
inside the range or outside the range. A single threshold passed to -c or -w will be treated as the range -Infinity to <threshold>, and
an alert will be triggered if the checked value is larger or equal to the threshold.

-c 2   -> critical alert triggered if the value is equal to or larger than 2
-c 2+  -> critical alert triggered if the value is larger than 2
-c :2  -> critical alert triggered if the value is equal to or less than 2
-c :2+  -> critical alert triggered if the value is less than 2

-c :1.99999999 is nearly identical to -c :2+

Contact:

Please report bugs and feature requests to magnus.luebeck@kmggroup.ch

EOT
end

#-------------------------------------------------------------------
# listMetrics
#-------------------------------------------------------------------
def listMetrics(namespace, instance_id)

  $stderr.puts "* Entering: #{thisMethod()}" if $debug

  aws_api = AWS::CloudWatch.new()

  case namespace
    when AWS_NAMESPACE_EC2
      dimensionCriteria="InstanceId"
    when AWS_NAMESPACE_RDS
      dimensionCriteria="DBInstanceIdentifier"
    when AWS_NAMESPACE_ELB
      dimensionCriteria="LoadBalancerName"
    else
      return 0
  end
  
  if (instance_id.nil?)
    dimensions = []
  else
    dimensions = [{:value => instance_id, :name => dimensionCriteria }]
  end

  metrics = aws_api.client.list_metrics({:namespace=> namespace, :dimensions =>dimensions}).data[:metrics]
  metrics.each do | metric |
   puts "====================== " + metric[:metric_name] + " ================================" if $debug
    pp metric if $debug
    if (!metric[:dimensions][0].nil?)
      puts "#{metric[:dimensions][0][:value]};#{metric[:metric_name]}"
    else
      puts ";#{metric[:metric_name]}"
    end
    
  end
end

#-------------------------------------------------------------------
# thisMethod, helper method to print the method name when debugging
#-------------------------------------------------------------------
def thisMethod
  caller[0]=~/`(.*?)'/  # note the first quote is a backtick
  $1
end

#--------------------------------------------------------
# parseThreshold
#--------------------------------------------------------

def parseThreshold(inputArg)

  $stderr.puts "* Entering: #{thisMethod()}" if $debug

  #--- check for range
  $stderr.puts "  - Parsing threshold #{inputArg}" if $debug
  arg = String.new( inputArg )

  values = {}
  softCheck = false
  values[:precision] = "hard"
  
  if (arg =~ /\+/)
    values[:precision] = "soft"
    arg.gsub!( /\+/, '')
  end
  
  if (arg =~ /^-?[0-9]+\.?[0-9]*$/)
    #--- only one value, range from 0 up to this value, check will be inside this range
    values[:type] = "outside-range"
    values[:floor] = (-1.0/0) # Infinity
    values[:ceiling] = arg.to_f()
  elsif (arg =~ /^-?[0-9]+\.?[0-9]*:$/)
    #--- only one value, range from this value up to infinity
    values[:type] = "inside-range"
    values[:floor] = arg.gsub!( /:/, '' ).to_f()
    values[:ceiling] = (+1.0/0.0)	# +Infinity
  elsif (arg =~ /^:-?[0-9]+\.?[0-9]*$/)
    #--- only one value, range from negative infinity up to this value
    arg.gsub!( /~/, '' )
    values[:type] = "inside-range"
    values[:floor] = (-1.0/0.0)	# -Infinity
    values[:ceiling] = arg.gsub!( /:/, '' ).to_f()
  elsif (arg =~ /^-?[0-9]+\.?[0-9]*:-?[0-9]+\.?[0-9]*$/)
    #--- two values, range from first to second value, check will be inside this range
    values_str = arg.split( /:/ )
    values[:type] = "inside-range"
    values[:floor] = values_str[0].to_f()
    values[:ceiling] = values_str[1].to_f()
  elsif (arg =~ /^@-?[0-9]+\.?[0-9]*:-?[0-9]+\.?[0-9]*$/)
    #--- two values, range from first to second value, check will be outside this range
    arg.gsub!( /@/, '' )
    values_str = arg.split( /:/ )
    #values_str.reverse!()
    values[:type] = "outside-range"
    values[:floor] = values_str[0].to_f()
    values[:ceiling] = values_str[1].to_f()
  else
    $stderr.puts "  - Could not parse this value (#{inputArg})" if $debug
    exit 1
  end

  $stderr.puts "  - values: #{values}" if $debug
  
  return values
end

#--------------------------------------------------------
# checkThreshold
#--------------------------------------------------------
def checkThreshold(checkValueStr, threshold)

  $stderr.puts "* Entering: #{thisMethod()}" if $debug

  checkValue = checkValueStr.to_f()
  
  $stderr.puts "  - checkValueStr: #{checkValueStr} checkValue: #{checkValue}" if $debug
  $stderr.puts "  - threshold type: #{threshold[:type]} floor: #{threshold[:floor]} ceiling: #{threshold[:ceiling]}" if $debug
  case threshold[:type]
  when "outside-range"
    $stderr.puts "  - Checking outside-range" if $debug
    case threshold[:precision]
    when "hard"
        #--- =c 2 -> a value of 2 or above will trigger
        if (checkValue <= threshold[:floor] || checkValue >= threshold[:ceiling] )
          $stderr.puts "  - Is outside the range #{threshold[:floor]} and #{threshold[:ceiling]}" if $debug
          return false
        end
    when "soft"
      #--- -c 2 -> a value larger than 2 will trigger
      if (checkValue < threshold[:floor] || checkValue > threshold[:ceiling] )
        $stderr.puts "  - Is outside the range #{threshold[:floor]} and #{threshold[:ceiling]}" if $debug
        return false
      end
    end      
  when "inside-range"
    puts "Checking inside-range #{threshold[:precision]}" if $debug
    case threshold[:precision]
    when "hard"
      if (checkValue >= threshold[:floor] && checkValue <= threshold[:ceiling] )
        return false
      end
    when "soft"
      if (checkValue > threshold[:floor] && checkValue < threshold[:ceiling] )
        return false
      end
    end
  end
  
  return true
end

#--------------------------------------------------------
# checkThresholds
#--------------------------------------------------------
def checkThresholds(checkValueStr, thresholdWarning, thresholdCritical)
  $stderr.puts "* Entering: #{thisMethod()}" if $debug

  if (!thresholdCritical.nil? && !checkThreshold(checkValueStr, thresholdCritical))
    return NAGIOS_CODE_CRITICAL
  elsif (!thresholdWarning.nil? && !checkThreshold(checkValueStr,thresholdWarning))
    return NAGIOS_CODE_WARNING
  else
    return NAGIOS_CODE_OK
  end
end
  
#============================================
# Parse options
#============================================

opts = GetoptLong.new
opts.set_options(
  [ "--help", "-h", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--region", "-r", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--access_key", "-a", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--instance", "-i", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--secret_key", "-s", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--list-metrics", "-l", GetoptLong::NO_ARGUMENT],
  [ "--namespace", "-N", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--metric", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--window", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--period", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--critical", "-c", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--warning", "-w", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--verbose", "-v", GetoptLong::NO_ARGUMENT],
  [ "--debug", GetoptLong::NO_ARGUMENT],
  [ "--statistics", GetoptLong::OPTIONAL_ARGUMENT],
  [ "--config", "-C", GetoptLong::OPTIONAL_ARGUMENT]
)

opts.each { |opt,arg|
  case opt
    when '--help'
      usage
      exit 0
    when '--config'
      configFile        = arg 
    when '--region'
      regionOverride    = arg
    when '--access_key'
      accessKeyOverride = arg
    when '--secret_key'
      secretKeyOverride = arg
    when '--instance'
      instance_id       = arg
    when '--namespace'
      namespace=arg
    when '--list-metrics'
      optListMetrics    = true
    when '--window'
      statisticsWindow  = arg.to_i
      optWindow = statisticsWindow
    when '--period'
      statisticsPeriod  = arg.to_i
      optPeriod         = statisticsPeriod
    when '--metric'
      metric            = arg
    when '--verbose'
      $verbose          = true
    when '--debug'
      $debug            = true
    when '--critical'
      thresholdCritical = parseThreshold(arg)
    when '--warning'
      thresholdWarning  = parseThreshold(arg)
    when '--statistics'
      statistics        = arg.split(/,/)
  end
}

#--- minor quirks

#--- if optPeriod is not set, the period should be equal to the window. It can be useful to use --window=3600 --period=60 --debug
#--- to see data points over a period of one hour
statisticsPeriod = statisticsWindow if optPeriod.nil?
$verbose = true if $debug

#============================================
# Config file (yml)
#============================================

if File.exist?(configFile)
  $stderr.puts "* Reading config file #{configFile}" if $debug
  config = YAML.load(File.read(configFile))
else
  $stderr.puts "WARNING: #{configFile} does not exist" if $verbose
end

#============================================
# Setup dimensions
#============================================

if namespace.eql?(AWS_NAMESPACE_EC2)
  dimensions = [{:name => "InstanceId", :value => instance_id} ]
elsif namespace.eql?(AWS_NAMESPACE_RDS)
  dimensions = [{:name => "DBInstanceIdentifier", :value => instance_id}]
elsif namespace.eql?(AWS_NAMESPACE_ELB)
  dimensions = [{:name => "LoadBalancerName", :value => instance_id}]
end

$stderr.puts "* Setting up dimensions to #{dimensions}" if $debug

#============================================
# Setup connection to AWS
#============================================

#pp config["aws"] if $debug

$stderr.puts "* AWS Config" if $debug

AWS.config(config["aws"]) unless config.nil?
#--- if --region was used
AWS.config(:region => regionOverride) unless regionOverride.to_s.empty?
#--- if --access_key was used
AWS.config(:access_key_id => accessKeyOverride) unless accessKeyOverride.to_s.empty?
#--- if --secret was used
AWS.config(:secret_access_key => secretKeyOverride) unless secretKeyOverride.to_s.empty?
#AWS.config(:namespace => secretKeyOverride) unless namespaceOverride.to_s.empty?

pp secretKeyOverride

#============================================
#============================================
#                   MAIN 
#============================================
#============================================


#--- list metrics
if (optListMetrics)
  listMetrics(namespace, instance_id)
  exit 0
end

$stderr.puts "* Creating AWS handle" if $verbose

begin                                                                                                                                                                
  aws_api = AWS::CloudWatch.new()
rescue Exception => e                                                                                                                                                
  puts "Error occured while trying to connect to AWS Endpoint: " + e.to_s                                                                                                 
  exit NAGIOS_CODE_CRITICAL                                                                                                                                          
end                                                                                                                                                                  

$stderr.puts  "* Gathering metrics" if $verbose
$stderr.puts "  - Namespace: #{namespace} Dimensions: #{dimensions} Metric: #{metric} Window: #{statisticsWindow} Period: #{statisticsPeriod}" if $debug

metrics = aws_api.client.get_metric_statistics(
  'metric_name' => metric,
  'period'      => statisticsPeriod,
  'start_time'  => (Time.now() - statisticsWindow).iso8601,
  'end_time'    => Time.now().iso8601,
  'statistics'  => statistics, #--- should normally be "Average", unless you want to sum up 
  'namespace'   => namespace,
  'dimensions'  => dimensions
)

#--- if the metrics need to be sorted

$stderr.puts "  - Number of elements #{metrics[:datapoints].count}" if $verbose

pp metrics if $debug

if (metrics[:datapoints].count == 0)
  $stderr.puts "No results from CloudWatch (probably no activity)" if $verbose
  output = {:average => 0, :minimum => 0, :maximum => 0, :sum => 0, :timestamp => "", :unit => 0}
elsif (metrics[:datapoints].count > 1)
  sortedMetrics = metrics[:datapoints].sort_by{|hsh| hsh[:timestamp]}.reverse
  output          = sortedMetrics[0]
else
  output          = metrics[:datapoints][0]
end

#--- check the thresholds
case statistics[0]
when 'Average'
  retCode=checkThresholds(output[:average], thresholdWarning, thresholdCritical)
when 'Minimum'
  retCode=checkThresholds(output[:minimum], thresholdWarning, thresholdCritical)
when 'Maximum'
  retCode=checkThresholds(output[:maximum], thresholdWarning, thresholdCritical)
when 'Count'
  retCode=checkThresholds(output[:count], thresholdWarning, thresholdCritical)
when 'Sum'
  retCode=checkThresholds(output[:sum], thresholdWarning, thresholdCritical)
end


puts "#{retCode[:msg]} - Metric: #{metric}, Last Average: #{output[:average]} #{output[:unit]} (#{output[:timestamp]})"

#--- output nagios perfdata format
print "|"

loopCount=0
statistics.each do |statistic|
  if (loopCount > 0)
    print ","
  end

  case statistic
  when "Average"
      print "#{statistic}=#{output[:average]}"
  when "Minimum"
      print "#{statistic}=#{output[:minimum]}"
  when "Maximum"
      print "#{statistic}=#{output[:maximum]}"
  when "Sum"
      print "#{statistic}=#{output[:sum]}"
  when "Count"
      print "#{statistic}=#{output[:count]}"
  end
  
  loopCount += 1
end  
puts #--- end of line

$stderr.puts "* Ret: #{retCode[:value].to_s}" if $verbose
exit retCode[:value]
