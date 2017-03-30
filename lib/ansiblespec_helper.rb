module AnsibleSpecHelper
  def self.get_properties
    playbook, inventoryfile = AnsibleSpec.load_ansiblespec

    hosts = AnsibleSpec.load_targets(inventoryfile)
    properties = AnsibleSpec.load_playbook(playbook)

    properties.each do |var|
      var["hosts_childrens"] = hosts["hosts_childrens"]
      var["group"] = var["hosts"]
      if var["hosts"].to_s == "all"
        var["hosts"] = hosts.values.flatten
      elsif hosts.has_key?("#{var["hosts"]}")
        var["hosts"] = hosts["#{var["hosts"]}"]
      elsif var["hosts"].instance_of?(Array)
        tmp_host = var["hosts"]
        var["hosts"] = []
        tmp_host.each do |v|
          if hosts.has_key?("#{v}")
            hosts["#{v}"].map {|target_server| target_server["hosts"] = v}
            var["hosts"].concat hosts["#{v}"]
          end
        end
        if var["hosts"].size == 0
          properties = properties.compact.reject{|e| e["hosts"].length == 0}
        end
      else
        var["hosts"] = []
      end
    end

    return properties
  end
end
