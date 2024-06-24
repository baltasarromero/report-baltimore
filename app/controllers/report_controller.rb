require 'benchmark'

class ReportController < ApplicationController
  unloadable
  before_action :require_admin
  
  def index
    @billing_types = []
    @grouped_projects = []
    @year = params[:year] || Time.current.year.to_s
    @previous_year = (@year.to_i - 1).to_s
    @next_year = (@year.to_i + 1).to_s
    @total_hours = {}∫

    elapsed_time = Benchmark.realtime do
      projects = get_invoiceable_projects()
      @billing_types = fetch_billing_types(projects)
      @grouped_projects = group_projects_by_billing_type(projects)
     
      non_billable_entry_id = TimeEntryActivity.find_by(name: 'No-Facturables')&.id

      @total_hours  = get_hours_by_project_month(@year, non_billable_entry_id, projects.map(&:id))
    end  

    logger.info("Elapsed time in controller: #{elapsed_time} seconds")
  end

  private

  def fetch_billing_types(projects)
    billing_type = CustomField.find_by(name: 'Tipo de Facturacion')
    return [] unless billing_type
  
    billing_types = projects.first.available_custom_fields
                               .select { |cf| cf.name == billing_type.name }
                               .first&.possible_values || []
  
    billing_types.push("") unless billing_types.include?("")
    billing_types
  end

  def group_projects_by_billing_type(projects)
    elapsed_time = Benchmark.realtime do
      billing_type = CustomField.find_by(name: 'Tipo de Facturacion')
      return {} unless billing_type
    
      projects.group_by { |proj| proj.custom_field_value(billing_type.id) }
    end 
    logger.info("Elapsed time grouping projects: #{elapsed_time} seconds") 
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
      # A value of 0 indicates that the project is NOT hidden for invoiving reports
      projects = Project.joins('INNER JOIN custom_values cv ON cv.customized_id = projects.id').where("cv.custom_field_id = #{hide_project_custom_field.id} and cv.value = 0");
    end
    logger.info("Elapsed time getting invoiceable projects: #{elapsed_time} seconds") 
    projects
  end  
end