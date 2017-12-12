class RecordMapper

    attr_reader :record

    def initialize(record)
        @record = record
    end

    def repo_code
        self.record.resolved_repository.dig('repo_code').downcase
    end

    def repo_settings
        AppConfig[:aeon_fulfillment][self.repo_code]
    end

    def show_action?
        false
    end


    # Pulls data from the contained record
    def map
        mappings = {}

        mappings['SystemID'] =
            if (!self.repo_settings[:aeon_external_system_id].blank?)
                self.repo_settings[:aeon_external_system_id]
            else
                "ArchivesSpace"
            end

        return_url =
            if (!AppConfig[:public_proxy_url].blank?)
                AppConfig[:public_proxy_url]
            elsif (!AppConfig[:public_url].blank?)
                AppConfig[:public_url]
            else
                ""
            end

        mappings['ReturnLinkURL'] = "#{return_url}#{self.record['uri']}"

        mappings['ReturnLinkSystemName'] =
            if (!self.repo_settings[:aeon_return_link_label].blank?)
                self.repo_settings[:aeon_return_link_label]
            else
                "ArchivesSpace"
            end

        # Merge in data from self.record.json
        mappings = mappings.merge(self.json_fields)

        # Data pulled from self.record and self.record.raw
        mappings['identifier'] = self.record.identifier || self.record['identifier']
        mappings['level'] = self.record.level || self.record['level']
        mappings['uri'] = self.record.uri || self.record['uri']

        resolved_resource = self.record['_resolved_resource'] || self.record.resolved_resource
        if resolved_resource
            resource_obj = resolved_resource[self.record['resource']]
            if resource_obj
                mappings['collection_id'] = "#{resource_obj[0]['id_0']} #{resource_obj[0]['id_1']} #{resource_obj[0]['id_2']} #{resource_obj[0]['id_3']}".rstrip
                mappings['collection_title'] = resource_obj[0]['title']
            end
        end

        mappings['language'] ||= self.record['language']
        mappings['publish'] = self.record['publish']
        mappings['title'] = self.record['title']

        if record['creators']
            mappings['creators'] = self.record['creators'].map { |k| "#{k}" }.join("; ")
        end

        return mappings
    end


    # Pulls relevant data from the record's JSON property
    def json_fields

        mappings = {}

        json = self.record.json
        if !json
            return mappings
        end

        mappings['language'] = json['language']

        if json['notes']
            json['notes'].each do |note|
                if note['type'] == 'physloc' and note['content'].length > 0
                    mappings['physical_location_note'] = note['content'].map { |cont| "#{cont}" }.join("; ")
                end
            end
        end

        if json['dates']
            json['dates'].each do |date|
                mappings["#{date['label']}_date"] = date['expression']
            end
        end

        mappings['restrictions_apply'] = json['restrictions_apply']
        mappings['display_string'] = json['display_string']

        instances = json.fetch('instances')
        if !instances
            return mappings
        end

        mappings['requests'] = []

        instance_count = 0
        instances.each do |instance|
            next if instance['digital_object']
            request = {}

            instance_count += 1

            request['Request'] = "#{instance_count}"

            request["instance_is_representative_#{instance_count}"] = instance['is_representative']
            request["instance_last_modified_by_#{instance_count}"] = instance['last_modified_by']
            request["instance_instance_type_#{instance_count}"] = instance['instance_type']
            request["instance_created_by_#{instance_count}"] = instance['created_by']

            request['instance_container_grandchild_indicator'] = instance['indicator_3']
            request['instance_container_child_indicator'] = instance['indicator_2']
            request['instance_container_grandchild_type'] = instance['type_3']
            request['instance_container_child_type'] = instance['type_2']

            container = instance['sub_container']
            if container
                request["instance_container_last_modified_by_#{instance_count}"] = container['last_modified_by']
                request["instance_container_created_by_#{instance_count}"] = container['created_by']

                top_container = container['top_container']
                if top_container
                    request["instance_top_container_uri_#{instance_count}"] = top_container['uri']

                    top_container_resolved = top_container['_resolved']
                    if top_container_resolved
                        request["instance_top_container_long_display_string_#{instance_count}"] = top_container_resolved['long_display_string']
                        request["instance_top_container_last_modified_by_#{instance_count}"] = top_container_resolved['last_modified_by']
                        request["instance_top_container_display_string_#{instance_count}"] = top_container_resolved['display_string']
                        request["instance_top_container_restricted_#{instance_count}"] = top_container_resolved['restricted']
                        request["instance_top_container_created_by_#{instance_count}"] = top_container_resolved['created_by']
                        request["instance_top_container_indicator_#{instance_count}"] = top_container_resolved['indicator']
                        request["instance_top_container_type_#{instance_count}"] = top_container_resolved['type']
                    end
                end
            end

            mappings['requests'] << request
        end

        return mappings
    end

    protected :json_fields
end
