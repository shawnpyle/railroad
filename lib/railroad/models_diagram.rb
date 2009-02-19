# RailRoad - RoR diagrams generator
# http://railroad.rubyforge.org
#
# Copyright 2007-2008 - Javier Smaldone (http://www.smaldone.com.ar)
# See COPYING for more details

# RailRoad models diagram
class ModelsDiagram < AppDiagram

  def initialize(options)
    #options.exclude.map! {|e| "app/models/" + e}
    super options
    @graph.diagram_type = 'Models'
    # Processed habtm associations
    @habtm = []
  end

  # Process model files
  def generate
    STDERR.print "Generating models diagram\n" if @options.verbose
    base = "(app/models/|lib/)"
    files = Dir.glob("app/models/**/*.rb")
    files += Dir.glob("vendor/plugins/**/app/models/*.rb") if @options.plugins_models
    files += Dir.glob("lib/**/*.rb") if @options.libraries

    files -= @options.exclude
    (files + ['filter_condition_type']).each do |file|
      model_name =
        @options.classes_by_files[file] ||
        (model_path = file.gsub(/^#{base}([\w_\/\\]+)\.rb/, '\2')).camelize
      STDERR.print "Processing #{file} ...\n" if @options.verbose
      # Hack to skip all xxx_related.rb files
      next if /_related/i =~ model_name

      klass = begin
                model_name.constantize
              rescue LoadError
                STDERR.print "\t#{model_name} raised LoadError.\n" if @options.verbose
                oldlen = model_path.length
                model_path.gsub!(/.*[\/\\]/, '')
                model_name = model_path.camelize
                if oldlen > model_path.length
                  retry
                end
                STDERR.print "\tDone trying to remove slashes, skipping this model.\n" if @options.verbose
                next
              rescue NameError
                STDERR.print "\t#{model_name} raised NameError, skipping this model.\n" if @options.verbose
                next
              end

      process_class klass
      STDERR.print "Done #{file}\n" if @options.verbose
    end
  end

  private

  # Load model classes
  def load_classes
    begin
      disable_stdout
      files = Dir.glob("app/models/**/*.rb")
      files += Dir.glob("vendor/plugins/**/app/models/*.rb") if @options.plugins_models
      files -= @options.exclude
      files.each do |m|
        require m
      end
      enable_stdout
    rescue LoadError
      enable_stdout
      print_error "model classes"
      raise
    end
  end  # load_classes

  # Process a model class
  def process_class(current_class)

    STDERR.print "\tProcessing #{current_class} ...\n" if @options.verbose

    generated = false

    # Is current_clas derived from ActiveRecord::Base?
    if current_class.respond_to?'reflect_on_all_associations'


      node_attribs = []
      if @options.brief || current_class.abstract_class? || current_class.superclass != ActiveRecord::Base
        node_type = 'model-brief'
      else
        node_type = 'model'

        # Collect model's content columns

        content_columns = current_class.content_columns

        if @options.hide_magic
          magic_fields = [
          # Restful Authentication
          "login", "crypted_password", "salt", "remember_token", "remember_token_expires_at", "activation_code", "activated_at",
          # From patch #13351
          # http://wiki.rubyonrails.org/rails/pages/MagicFieldNames
          "created_at", "created_on", "updated_at", "updated_on",
          "lock_version", "type", "id", "position", "parent_id", "lft",
          "rgt", "quote", "template"
          ]
          magic_fields << current_class.table_name + "_count" if current_class.respond_to? 'table_name'
          content_columns = current_class.content_columns.select {|c| ! magic_fields.include? c.name}
        else
          content_columns = current_class.content_columns
        end

        content_columns.each do |a|
          content_column = a.name
          content_column += ' :' + a.type.to_s unless @options.hide_types
          node_attribs << content_column
        end
      end
      @graph.add_node [node_type, current_class.name, node_attribs]
      generated = true
      # Process class associations
      associations = current_class.reflect_on_all_associations
      if @options.inheritance && ! @options.transitive
        superclass_associations = current_class.superclass.reflect_on_all_associations

        associations = associations.select{|a| ! superclass_associations.include? a}
        # This doesn't works!
        # associations -= current_class.superclass.reflect_on_all_associations
      end
      associations.each do |a|
        process_association current_class.name, a
      end
    elsif @options.all && (current_class.is_a? Class)
      # Not ActiveRecord::Base model
      node_type = @options.brief ? 'class-brief' : 'class'
      @graph.add_node [node_type, current_class.name]
      generated = true
    elsif @options.modules && (current_class.is_a? Module)
        @graph.add_node ['module', current_class.name]
    end

    # Only consider meaningful inheritance relations for generated classes
    if @options.inheritance && generated &&
       (current_class.superclass != ActiveRecord::Base) &&
       (current_class.superclass != Object)
      @graph.add_edge ['is-a', current_class.superclass.name, current_class.name]
    end

    STDERR.print "\tDone #{current_class}\n" if @options.verbose
  end # process_class

  # Process a model association
  def process_association(class_name, assoc)
    begin
    STDERR.print "\t\tProcessing model association #{assoc.name.to_s} ..." if @options.verbose

    # Skip "belongs_to" associations
    return if assoc.macro.to_s == 'belongs_to'

    # Only non standard association names needs a label

    # from patch #12384
    # if assoc.class_name == assoc.name.to_s.singularize.camelize
    assoc_class_name = (assoc.class_name.respond_to? 'underscore') ? assoc.class_name.underscore.singularize.camelize : assoc.class_name
    if assoc_class_name == assoc.name.to_s.singularize.camelize
      assoc_name = ''
    else
      assoc_name = assoc.name.to_s
    end
#    STDERR.print "#{assoc_name}\n"
    if assoc.macro.to_s == 'has_one'
      assoc_type = 'one-one'
    elsif assoc.macro.to_s == 'has_many' && (! assoc.options[:through])
      assoc_type = 'one-many'
    else # habtm or has_many, :through
      return if @habtm.include? [assoc.class_name, class_name, assoc_name]
      assoc_type = 'many-many'
      @habtm << [class_name, assoc.class_name, assoc_name]
    end
    # from patch #12384
    # @graph.add_edge [assoc_type, class_name, assoc.class_name, assoc_name]
    @graph.add_edge [assoc_type, class_name, assoc_class_name, assoc_name]
    ensure
      STDERR.print " done.\n" if @options.verbose
    end
  end # process_association

end # class ModelsDiagram
