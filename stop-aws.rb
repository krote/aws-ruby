require "aws-sdk"

AWS.config(YAML.load(File.read("./aws-config.yml")))

rds = AWS::RDS.new()
response = rds.client.describe_db_instances()

p "start"

response[:db_instances].each do |cur_instance|

	p "This rds id is ... " + cur_instance[:db_instance_identifier]
	final_db_snapshot = "#{cur_instance[:db_instance_identifier]}-final-snapshot"

	backup_snapshot = nil
	response2 = rds.client.describe_db_snapshots({:db_instance_identifier=>cur_instance[:db_instance_identifier]})
	response2[:db_snapshots].each do |cur_snapshot|
		if cur_snapshot[:db_snapshot_identifier] == final_db_snapshot
			backup_snapshot = cur_snapshot
		end
	end

	if backup_snapshot != nil
		p "delete old snaphost ..."
		rds.client.delete_db_snapshot({:db_snapshot_identifier=>backup_snapshot[:db_snapshot_identifier]})
		sleep(10)
	end

	p "make snahoshot : " + final_db_snapshot
	rds.client.create_db_snapshot({:db_instance_identifier=>cur_instance[:db_instance_identifier], :db_snapshot_identifier=>final_db_snapshot})
	status = "creating"
	while status != "available" do
		sleep(20)
		p "check snapshot status ..."
		response2 = rds.client.describe_db_snapshots({:db_snapshot_identifier=>final_db_snapshot})
		status = response2[:db_snapshots][0][:status]
		p "snapshot staus is : " + status
	end
	p "snapshot done"
	p "delete instance ..."
	rds.client.delete_db_instance({:db_instance_identifier=>cur_instance[:db_instance_identifier], :skip_final_snapshot=>true})
	p "now deleting"
end

ec2 = AWS::EC2.new()
response = ec2.client.describe_instances()
response[:reservation_set].each do |reservation|
	cur_instance = reservation[:instances_set][0]
	p cur_instance[:instance_id] + " is " + cur_instance[:instance_state][:name]
	if cur_instance[:instance_state][:name] == "running"
		p "stop ec2 ... "
		ec2.client.stop_instances({:instance_ids=>[cur_instance[:instance_id]]})
		p "stop is running"
	end
end

p "end"
