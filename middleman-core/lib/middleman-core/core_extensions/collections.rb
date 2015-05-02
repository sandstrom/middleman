require 'middleman-core/core_extensions/collections/pagination'
require 'middleman-core/core_extensions/collections/step_context'
require 'middleman-core/core_extensions/collections/lazy_root'
require 'middleman-core/core_extensions/collections/lazy_step'

# Super "class-y" injection of array helpers
class Array
  include Middleman::Pagination::ArrayHelpers
end

module Middleman
  module CoreExtensions
    module Collections
      class CollectionsExtension < Extension
        # This should run after most other sitemap manipulators so that it
        # gets a chance to modify any new resources that get added.
        self.resource_list_manipulator_priority = 110

        attr_accessor :sitemap_collector, :data_collector, :leaves

        # Expose `resources`, `data`, and `collection` to config.
        expose_to_config resources: :sitemap_collector,
                         data: :data_collector,
                         collection: :register_collector

        # Exposes `collection` to templates
        expose_to_template collection: :collector_value

        helpers do
          def pagination
            current_resource.data.pagination
          end
        end

        def initialize(app, options_hash={}, &block)
          super

          @leaves = Set.new
          @collectors_by_name = {}
          @values_by_name = {}

          @sitemap_collector = LazyCollectorRoot.new(self)
          @data_collector = LazyCollectorRoot.new(self)
        end

        def before_configuration
          @leaves.clear
        end

        Contract Symbol, LazyCollectorStep => Any
        def register_collector(label, endpoint)
          @collectors_by_name[label] = endpoint
        end

        Contract Symbol => Any
        def collector_value(label)
          @values_by_name[label]
        end

        Contract ResourceList => ResourceList
        def manipulate_resource_list(resources)
          @sitemap_collector.realize!(resources)
          @data_collector.realize!(app.data)

          ctx = StepContext.new
          leaves = @leaves.dup

          @collectors_by_name.each do |k, v|
            @values_by_name[k] = v.value(ctx)
            leaves.delete v
          end

          # Execute code paths
          leaves.each do |v|
            v.value(ctx)
          end

          # Inject descriptors
          resources + ctx.descriptors.map { |d| d.to_resource(app) }
        end
      end
    end
  end
end
