class ReportController < ApplicationController
  unloadable
  before_action :require_admin
  
  def index
    projects = get_invoiceable_projects()
    @billing_types = fetch_billing_types(projects)
    @grouped_projects = group_projects_by_billing_type(projects)
    @year = params[:year] || Time.current.year.to_s
    @previous_year = (@year.to_i - 1).to_s
    @next_year = (@year.to_i + 1).to_s
    non_billable_entry_id = TimeEntryActivity.find_by(name: 'No-Facturables')&.id

    @total_hours  = get_hours_by_project_month(@year, non_billable_entry_id, projects.map(&:id))
  end

  private

  def fetch_billing_types(projects)
    billing_types = []
    elapsed_time = Benchmark.realtime do
      billing_type = CustomField.find_by(name: 'Tipo de Facturacion')
      return [] unless billing_type
    
      billing_types = projects.first.available_custom_fields
                                .select { |cf| cf.name == billing_type.name }
                                .first&.possible_values || []
    
      billing_types.push("") unless billing_types.include?("")
    end
    logger.info("Elapsed time getting billing types: #{elapsed_time} seconds")   
    billing_types
  end

  def group_projects_by_billing_type(projects)
    projects_by_billing_type = {}
    elapsed_time = Benchmark.realtime do
      # Convert to a dictionary of dictionaries
      projects_by_billing_type = projects.each_with_object({}) do |project, hash|
        hash[project.billing_type] ||= [] # Initialize an empty array if not already present
        hash[project.billing_type] << project
      end

      projects_by_billing_type.keys.each do |key|
        projects_by_billing_type[key] = projects_by_billing_type[key].sort_by(&:name)
      end
    end

    logger.info("Elapsed time grouping and ordering projects: #{elapsed_time} seconds")  
    projects_by_billing_type
  end

  def group_projects_by_billing_type_old(projects)
    billing_type = CustomField.find_by(name: 'Tipo de Facturacion')
    return {} unless billing_type
  
    projects.group_by { |proj| proj.custom_field_value(billing_type.id) }
  end

  def get_hours_by_project_month(year, non_billable_entry_id, billable_projects_ids)
    time_entries_dict = {}
    elapsed_time = Benchmark.realtime do
      time_entries = TimeEntry.select('project_id, tmonth AS month, SUM(hours) AS total_monthly_hours').where(tyear: year).where.not(activity_id: non_billable_entry_id).where(project_id: billable_projects_ids).group(:project_id, :tmonth).order(:project_id, :tmonth)
      
      # Convert to a dictionary of dictionaries
      time_entries_dict = time_entries.each_with_object({}) do |entry, hash|
        hash[entry.project_id] ||= {}
        hash[entry.project_id][entry.month] = entry.total_monthly_hours
      end
    end  
    logger.info("Elapsed time getting time entries: #{elapsed_time} seconds") 
    time_entries_dict
  end  

  def get_invoiceable_projects()
    projects = []
    elapsed_time = Benchmark.realtime do
      # Get the id of the custom field needed
      hide_project_custom_field = CustomField.find_by(name: 'Ocultar en Facturacion')
      # Get the id of the custom field needed
      billing_type = CustomField.find_by(name: 'Tipo de Facturacion')
      # A value of 0 for the custom field indicates that the project is NOT hidden for invoiving reports   
      projects = Project
      .joins("INNER JOIN custom_values cvof ON cvof.customized_id = projects.id AND cvof.customized_type = 'Project' AND cvof.custom_field_id = #{hide_project_custom_field.id} AND cvof.value = 0")
      .joins("INNER JOIN custom_values cvbt ON cvbt.customized_id = projects.id AND cvbt.customized_type = 'Project' AND cvbt.custom_field_id = #{billing_type.id}")
      .joins("LEFT JOIN enabled_modules em ON em.project_id = projects.id AND em.name = 'proformanext'")
      .select("projects.id, projects.name, projects.identifier, cvbt.value AS billing_type, 
          CASE WHEN em.id IS NOT NULL THEN TRUE ELSE FALSE END AS proformanext_enabled")

      .order("billing_type ASC")
    end
    logger.info("Elapsed time getting invoiceable projects: #{elapsed_time} seconds") 
    
    #rendered_projects = render json: projects
    projects
  end  
end