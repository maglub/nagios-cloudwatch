
#Releases

Currently the pace of development is very high. Any downloads of the "master" branch will be subject of rapid change.

If you want a stable release, please download from the "stable" branch. The latest release can be found here:

* https://github.com/maglub/nagios-cloudwatch/archive/stable.tar.gz

#Description

Nagios Cloudwatch is a set of scripts to help with the Nagios (and derivates) monitoring of Amazon Cloud resources.

Possible checks:

* Amazon EC2 statuses
  * Instance running
  
* Amazon Cloudwatch statistics
  - Reading/reporting on EC2 instance statistics metrics, such as CPUUtilization, etc
  - Reading/reporging on ELB statistics, such as HealthyHostCount, Latency, etc

#Pre-requisites

* Ruby environment with ruby version > 1.9.1 (see below)
* Ruby 1.8.7 (current release on OP5 servers) works too
* Note! As of 2016-02-05, this script does not work with ruby >2.0, sorry
* Configuration file config.yml, unless you supply the credentials on the command line

#Installation:

## This git repo

````
mkdir /path/to/your/plugins
cd /path/to/your/plugins
git clone git@github.com:maglub/nagios-cloudwatch.git
````


## AWS

* Create a new policy for read only access: https://console.aws.amazon.com/iam/home?region=us-west-2#policies
** Create your own policy, policy name (example) "KMG-Group-AWS-Monitoring", Description (example) "Read only policy needed for read only access for external AWS monitoring"

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "autoscaling:Describe*",
      "Resource": "*"
    }
  ]
}
```

* Create a new user (which will get read only access): https://console.aws.amazon.com/iam/home?region=us-west-2#users
** Make sure you save the credentials/tokens
** Attach the policy above


## config.yml

* Create a read-only user in AWS and associate it with your environment
* Put the access key and secret key in a config.yml file in the same directory as these scripts (or somewhere else if you intend to use the -C parameter)

````
aws:
  #======================
  #--- authentication
  #======================
  access_key_id: YOUR_ACCESS_KEY
  secret_access_key: YOUR_SECRET_KEY
  
  #========================================
  #--- default region, unless overridden on the command line
  #========================================
  #--- possible regions us-west-1 us-west-2 eu-west-1, etc...
  region: us-west-2

  #======================
  #--- Proxy config
  #======================
  #proxy_uri: http://user:passwd@IP:PORT

````

## Ruby
### FreeBSD 10 (ruby 2.2.5 / AWS SDK v2)
````
pkg install ruby rubygem-aws-sdk ca_root_nss git
git clone https://github.com/laurencegill/nagios-cloudwatch.git
````

### Ubuntu 14.04 LTS (ruby 1.9.3)

````
sudo apt-get -y install ruby-dev libxslt-dev libxml2-dev
sudo gem install aws-sdk -v 1.15
wget -O - https://github.com/maglub/nagios-cloudwatch/tarball/master | tar xvzf -
````

### Ubuntu 12.04 LTS (ruby 1.9.3)

On new Ubuntu 12.04 LTS installs, same as above (Ubuntu 14.04 LTS)
For older installs, you might have to try the instructions here. If your installation come with ruby 1.8, you might have to start the script with `/usr/bin/ruby1.9.1 ./check_cloudwatch.rb`, unless you follow the second step on how to make ruby1.9.1 default in your installation.


````
sudo apt-get install -y ruby1.9.1 ruby1.9.1-dev \
     rubygems1.9.1 irb1.9.1 ri1.9.1 rdoc1.9.1 \
	 build-essential libopenssl-ruby1.9.1 libssl-dev zlib1g-dev

sudo apt-get install libxslt-dev libxml2-dev
sudo apt-get install build-essential

sudo gem install aws-sdk -v 1.15 	
````

Note: to make ruby1.9.1 default on your system, follow the instructions on:

* https://leonard.io/blog/2012/05/installing-ruby-1-9-3-on-ubuntu-12-04-precise-pengolin/

````
sudo apt-get update
 
sudo apt-get install ruby1.9.1 ruby1.9.1-dev \
   rubygems1.9.1 irb1.9.1 ri1.9.1 rdoc1.9.1 \
   build-essential libopenssl-ruby1.9.1 libssl-dev zlib1g-dev
 
sudo update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 400 \
          --slave   /usr/share/man/man1/ruby.1.gz ruby.1.gz \
                         /usr/share/man/man1/ruby1.9.1.1.gz \
         --slave   /usr/bin/ri ri /usr/bin/ri1.9.1 \
         --slave   /usr/bin/irb irb /usr/bin/irb1.9.1 \
         --slave   /usr/bin/rdoc rdoc /usr/bin/rdoc1.9.1
 
 # choose your interpreter
 # changes symlinks for /usr/bin/ruby , /usr/bin/gem
 # /usr/bin/irb, /usr/bin/ri and man (1) ruby
 sudo update-alternatives --config ruby
 sudo update-alternatives --config gem
 
 # now try
 ruby --version
````


### RedHat/CentOS 6.7 (ruby 1.8.7)

````
sudo yum install -y gcc make \
libxml2 libxml2-devel libxslt libxslt-devel \
rubygems ruby-devel

sudo gem install nokogiri -v '1.5.0' -- --with-xml2-lib=/usr/local/lib \
  --with-xml2-include=/usr/local/include/libxml2 \
  --with-xslt-lib=/usr/local/lib \
  --with-xslt-include=/usr/local/include

sudo gem install aws-sdk -v 1.15.0 --no-ri --no-rdoc

wget -O - https://github.com/maglub/nagios-cloudwatch/tarball/master | tar xvzf -
````

### RedHat/CentOS 7.1 (ruby 1.9.3)

````
sudo yum -y update
sudo yum -y install centos-release-scl
sudo yum -y install ruby193 gem

sudo yum install -y gcc make \
  libxml2 libxml2-devel libxslt libxslt-devel \
  rubygems ruby-devel

sudo gem install aws-sdk -v 1.15.0 --no-ri --no-rdoc
wget -O - https://github.com/maglub/nagios-cloudwatch/tarball/master | tar xvzf -
````

## OP5 Appliance (CentOS)

Pre-requisites already in place.

#Usage

## Examples

* Check an ELB (Elastic Load Balancer) for the number of healthy hosts. 

````
./check_cloudwatch.rb --instance="<INSTANCE_NAME>" --namespace="AWS/ELB" --metric="HealthyHostCount" --window=120 --period=60 --critical=:1+ --warning=:2+
OK - Metric: HealthyHostCount, Last Average: 2.0 Count (2014-06-14 13:34:00 UTC)
|Average=2.0,Minimum=2.0,Maximum=2.0,Sum=240.0
````

* Check an ELB for the total number of ok requests over the last 5 minutes, warning when the number of requests equal or exceed 10 requests, critical at 15

````
./check_cloudwatch.rb -i <INSTANCE_NAME> --window=3600 --metric=HTTPCode_Backend_2XX --window=300 --period=300 --critical=15 --warning=10 --statistics="Sum"
````

## Thresholds

* --warning={@}<threshold>{+}, -w {@}<threshold>{+}
* --critical={@}<threshold>{+}, -c {@}<threshold>{+}

The threshold parameter can be a single value or a range, and can handle decimal values.

* A threshold can be checked to be within a range, or outside a range.
* To alert when a value is outside a range, use the prefix "@".

The thresholds can be "soft" or "hard", meaning that ha hard threshold will include the parameter value (by comparing >= or <=). A soft threshold means that the check will not trigger when the checked value is equal to the threshold value (by comparing > or <).

A soft threshold is selected by suffixing "+" to the threshold.

Examples of valid thresholds are:

1, 1.0, 1:+, :1.5, 0:1000, @1:100

* "-c 75"    will trigger when the value is equal to or larger than 75
* "-c 75+"   will trigger when the value is larger than 75
* "-c 0:1"   will trigger when the value is equal to or larger than 0 and equal to or less than 1 
* "-c 0:1+"  will trigger when the value is larger than 0 and less than 1
* "-c @0:1+"  will trigger when the value is outside the soft range


## Listing metrics

You can list available metrics for your instance, your load balancer, etc, by using the --list-metrics parameter.

````
  ./check_cloudwatch.rb --namespace="AWS/EC2" -i <instance_id> --list-metrics
````

## Statistics window, and statistics period

The collection of AWS metrics is not done every minute. For example CPUUtilization is collected every 5 minutes. If you are asking for a window of 60 seconds and a period of 60 seconds, it is very likely that Cloudwatch will return an empty result set since there is no data to be presented for that period. This is a feature of the AWS Cloudwatch.

The workaround for this is to ask for a longer period, say 10 minutes or longer, to make sure you will get at least one metric in your result set.

````
  ./check_cloudwatch.rb --namespace="AWS/EC2" -i <instance_id> --metric="CPUUtilization" --window=600 --period=60
````
  


