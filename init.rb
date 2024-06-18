Redmine::Plugin.register :report do
  name 'Billing report plugin'
  author 'Leandro Perez Torres & German Vicentin'
  # description 'This is a plugin for Redmine'
  version '0.0.1'
  # url 'http://example.com/path/to/plugin'
  # author_url 'http://example.com/about'

  menu :top_menu, :global_activity, { :controller => 'report', :action => 'index', :year => Time.now.year }, :last => true, :caption => "Facturación", :if => Proc.new { User.current.admin? }
end