#Pre-requisites

* Ruby environment with ruby version > 1.9.1 (see below)
* Configuration file config.yml, unless you supply the credentials on the command line

#Installation:

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

## This git repo

````
mkdir /path/to/your/plugins
git clone git@github.com:maglub/nagios-cloudwatch.git
````

## Ruby
### Ubuntu 12.04 LTS

sudo apt-get install -y ruby1.9.1 ruby1.9.1-dev \
     rubygems1.9.1 irb1.9.1 ri1.9.1 rdoc1.9.1 \
	 build-essential libopenssl-ruby1.9.1 libssl-dev zlib1g-dev

sudo gem install aws-sdk-core --pre

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

### RedHat/CentOS

https://gist.github.com/trevorrowe/1870314

	sudo yum install -y gcc make \
	libxml2 libxml2-devel libxslt libxslt-devel \
	rubygems ruby-devel
	 
	sudo gem install nokogiri -- --with-xml2-lib=/usr/local/lib \
	--with-xml2-include=/usr/local/include/libxml2 \
	--with-xslt-lib=/usr/local/lib \
	--with-xslt-include=/usr/local/include
	 
	sudo gem install aws-sdk --no-ri --no-rdoc


#Usage

## Examples

## Listing metrics

You can list available metrics for your instance, your load balancer, etc, by using the --list-metrics parameter.

  ./check_cloudwatch.rb --namespace="AWS/EC2" -i <instance_id> --list-metrics

## Statistics window, and statistics period

The collection of AWS metrics is not done every minute. For example CPUUtilization is collected every 5 minutes. If you are asking for a window of 60 seconds and a period of 60 seconds, it is very likely that Cloudwatch will return an empty result set since there is no data to be presented for that period. This is a feature of the AWS Cloudwatch.

The workaround for this is to ask for a longer period, say 10 minutes or longer, to make sure you will get at least one metric in your result set.

  ./check_cloudwatch.rb --namespace="AWS/EC2" -i <instance_id> --metric="CPUUtilization" --window=600 --period=60
  


