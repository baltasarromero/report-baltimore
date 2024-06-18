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
    @total_hours = calculate_total_hours(projects)
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
    billing_type = CustomField.find_by(name: 'Tipo de Facturacion')
    return {} unless billing_type
  
    projects.group_by { |proj| proj.custom_field_value(billing_type.id) }
  end

  def calculate_total_hours(projects)
    total_hours = {}
    non_billables_id = TimeEntryActivity.find_by(name: 'No-Facturables')&.id
  
    projects.each do |proj|
      logger.info("Project id #{proj.id}, #{proj.name}")
      month_hours = {}
      (1..12).each do |month|
        monthly_hours = get_total_monthly_hours(proj.id, month, @year, non_billables_id)
        month_hours[month] = monthly_hours if monthly_hours > 0
      end
      total_hours[proj.id] = month_hours  
    end
  
    total_hours
  end

  def project_time_entries(project_id, month, year, non_billables_id)
    time_entries = TimeEntry.where("tmonth = ? and tyear = ? and project_id = ?",
                                   month, year, project_id).where.not("activity_id = ?", non_billables_id)
  end

  def get_total_monthly_hours(project_id, month, year, non_billables_id)
    time_entries = project_time_entries(project_id, month, year, non_billables_id)

    time_entries.sum(:hours).to_i
  end

  def get_invoiceable_projects()
    # Get the id of the custom field needed
    hide_project_custom_field = CustomField.find_by(name: 'Ocultar en Facturacion')
    # A value of 0 indicates that the project is NOT hidden for invoiving reports
    Project.joins('INNER JOIN custom_values cv ON cv.customized_id = projects.id').where("cv.custom_field_id = #{hide_project_custom_field.id} and cv.value = 0");
  end
end