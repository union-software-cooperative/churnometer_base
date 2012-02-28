# Short names to help shorten URL
Filter = "f"
FilterNames = "fn"

module Mappings
  class << self
    def groups_by_collection
      {
        "branchid"      => "Branch",
        "lead"          => "Lead Organiser",
        "org"           => "Organiser",
        "areaid"        => "Area",
        "companyid"     => "Work Site",
        "industryid"    => "Industry",
        "del"           => "Delegate Training",
        "hsr"           => "HSR Training",
        "nuwelectorate" => "Electorate",
        "state"         => "State",
        "feegroupid"    => "Fee Group"
      }
    end
  end
end