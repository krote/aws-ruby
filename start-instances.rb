require "aws-sdk"
require './config/instances.rb'

WAIT_TIME = 60

AWS.config(YAML.load(File.read("./config/aws-config.yml")))

# 先にRDSを立ち上げます
rds = AWS::RDS.new()
response = rds.client.describe_db_instances()

p "start"

p "check RDS"
$rds_instances.each do |target_rds_instance|
	demo_rds_instance = nil
	response[:db_instances].each do |cur_instance|
		p cur_instance[:vpc_security_groups]
		if cur_instance[:db_instance_identifier] == target_rds_instance[:db_instance_id]
			# すでにRDSは立ち上がっている
			p "RDS(" + target_rds_instance[:db_instance_id] + ") status is " + cur_instance[:db_instance_status]
			p cur_instance[:db_security_groups]
			demo_rds_instance = cur_instance
		end
	end

	if demo_rds_instance == nil
		# RDS を restore する
		response2 = rds.client.describe_db_snapshots({:db_instance_identifier=>target_rds_instance[:db_instance_id]})
		snapshots = response2[:db_snapshots].sort{|x,y| y[:db_snapshot_identifier] <=> x[:db_snapshot_identifier]}

		p "restore from db snapshot from " + snapshots[0][:db_snapshot_identifier]
		rds.client.restore_db_instance_from_db_snapshot({:db_instance_identifier=>target_rds_instance[:db_instance_id], :db_snapshot_identifier=>snapshots[0][:db_snapshot_identifier], :db_instance_class=>target_rds_instance[:db_instance_class], :availability_zone=>"ap-northeast-1a", :multi_az=>false, :db_name=>"ORCL"})

		status = "creating"
		while status != "available" do
			sleep(WAIT_TIME)
			p "check rds status "
			response2 = rds.client.describe_db_instances({:db_instance_identifier=>target_rds_instance[:db_instance_id]})
			status = response2[:db_instances][0][:db_instance_status]
			p "rds staus is :" + status
		end
		p "done"

		# Modify instance
		p "modify parameter settings ..."
		rds.client.modify_db_instance({:db_instance_identifier=>target_rds_instance[:db_instance_id], :vpc_security_group_ids=>[target_rds_instance[:db_security_group_id]] ,:db_parameter_group_name=>target_rds_instance[:db_parameter_group]})

		status = "modify"
		while status != "available" do
			sleep(WAIT_TIME)
			p "check rds status "
			response2 = rds.client.describe_db_instances({:db_instance_identifier=>target_rds_instance[:db_instance_id]})
			status = response2[:db_instances][0][:db_instance_status]
			p "rds staus is :" + status
		end
		p "done"

		# reboot instance
		p "reboot to use new settings ..."
		rds.client.reboot_db_instance({:db_instance_identifier=>target_rds_instance[:db_instance_id]})

		status = "rebooting..."
		while status != "available" do
			sleep(WAIT_TIME)
			p "check rds status "
			response2 = rds.client.describe_db_instances({:db_instance_identifier=>target_rds_instance[:db_instance_id]})
			status = response2[:db_instances][0][:db_instance_status]
			p "rds staus is :" + status
		end

		p "rds (" + target_rds_instance[:db_instance_id] + ") started!"
	else
		p "rds (" + target_rds_instance[:db_instance_id] + ") is already started!"
	end
end

p "check EC2"
ec2 = AWS::EC2.new()
$ec2_instances.each do |target_ec2_instance|
	instance = ec2.instances[target_ec2_instance[:ec2_instance_id]]
	if instance.status == :stopped
		p "ec2(" + target_ec2_instance[:ec2_instance_id] + ") is now stopped. start ec2..."
		instance.start
		status = "starting"
		while status != :running do
			sleep(WAIT_TIME)
			instance = ec2.instances[target_ec2_instance[:ec2_instance_id]]
			status = instance.status
			p status
		end
		p "ec2 (" + target_ec2_instance[:ec2_instance_id] + ") started!"
	else
		p "ec2 (" + target_ec2_instance[:ec2_instance_id] + ") is already started!"
	end
end

p "end"


