module Resourceful
  module Default
    module Accessors
     protected
      def current_objects
        @current_objects ||= current_model.find(:all, :include => model_includes)
      end

      def load_objects
        instance_variable_set("@#{instance_variable_name}", current_objects)
      end

      def current_object
        @current_object ||= current_model.find(current_param)
      end

      def load_object
        instance_variable_set("@#{instance_variable_name.singularize}", current_object)
      end

      def build_object
        @current_object = if current_model.respond_to? :build
          current_model.build(object_parameters)
        else
          current_model.new(object_parameters)
        end

        # This is where we assign all of the associations
        # and figure out how they work.
        #
        # This is currently setup back in builder
        # with associated_with :current_something
        associations = self.class.read_inheritable_attribute :resourceful_associations
        associations.each do |association_name, assign_with|
          associated_object = send(association_name)

          possible_method = if assign_with
            assign_with.to_s
          else
            associated_object.class.to_s.underscore
          end

          if @current_object.respond_to? possible_method
            @current_object.send(possible_method + "=", associated_object)
          else
            logger.warn "Association failed!"
          end
        end
      end

      def current_model_name
        controller_name.singularize.camelize
      end

      def namespaces
        @namespaces ||= self.class.name.split('::').slice(0..-2).map(&:underscore).map(&:to_sym)
      end

      def instance_variable_name
        controller_name.underscore.gsub /_controller$/, ""
      end

      def current_model
        if parent_objects.empty?
          current_model_name.constantize
        else
          parent_objects[-1].send(instance_variable_name)
        end
      end

      def current_param
        params[:id]
      end

      def object_parameters
        params[instance_variable_name.singularize.to_sym]
      end

      def model_includes
        Hash.new
      end

      def response_for(action)
        send("response_for_#{action}")
      end

      def parents
        self.class.read_inheritable_attribute :parents
      end

      def parent_model_names
        parents.map { |p| p.camelize }
      end

      def parent_models
        parent_model_names.map { |p| p.constantize }
      end

      def parent_params
        parents.map { |p| params["#{p}_id"].to_i }
      end

      # Returns an array of all of the parent objects
      # as defined in belongs_to :thing
      #
      # Currently only works for one parameter
      #
      # TODO: Expand this to handle more than one parent
      def parent_objects
        return [] if parents.empty?
        return @parent_objects if @parent_objects

        first = parent_models[0].find(parent_params[0])
        @parent_objects = [first]
        parent_params.zip(parents)[1..-1].inject(first) do |memo, arr|
          id, name = arr
          @parent_objects << memo.send(name.pluralize).find(id)
        end
        @parent_objects
      end

      def load_parent_objects
        parents.zip(parent_objects).map { |name, obj| instance_variable_set("@#{name}", obj) }
      end
    end
  end
end
