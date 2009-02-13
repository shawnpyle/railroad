namespace :doc do
  namespace :diagram do
    desc "Draw model diagram"
    task :models do
      classmap = {
#        'app/models/model_with_nasty_name' => 'ModelWithNastyNAME',
      }.to_a.join(',')
      exclude =
        [
#         'app/models/model_to_exclude.rb',
        ].join(',')
      opts =
        [
         '--models',
         '--inheritance',
         '--label',
         '--all',
         '--modules',
#         '--libraries',
#         '--verbose',
        ].join(' ')
      FileUtils.mkdir('doc/app') unless File.exist?('doc/app')
      sh "railroad #{opts} --class-map=#{classmap} --exclude=#{exclude} | dot -Tsvg | sed 's/font-size:14.00/font-size:11px/g' > doc/app/models.svg"
    end

    desc "Draw controller diagram"
    task :controllers do
      FileUtils.mkdir('doc/app') unless File.exist?('doc/app')
      sh "railroad -i -C | neato -Tsvg | sed 's/font-size:14.00/font-size:11px/g' > doc/app/controllers.svg"
    end
  end

  desc "Draw model & controller diagrams"
  task :diagrams => %w(diagram:models diagram:controllers)
end
