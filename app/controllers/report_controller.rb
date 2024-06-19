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
    non_billables_id = TimeEntryActivity.find_by(name: 'No-Facturables')&.id


    @total_hours  = get_hours_by_project_month(@year, non_billables_id, projects.map(&:id))
  
    #@total_hours = calculate_total_hours(projects, time_entries_dict)
  
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

  def calculate_total_hours(projects, time_entries_dict)
    total_hours = {}

    projects.each do |proj|
      month_hours = {}
      (1..12).each do |month|
        # Ensure that proj.id and month exist in the dictionary
        if time_entries_dict.key?(proj.id) && time_entries_dict[proj.id].key?(month)
          month_hours[month] = time_entries_dict[proj.id][month]
        end
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

  def get_hours_by_project_month(year, non_billables_id, billable_projects_ids)
    logger.info("billable project ids #{billable_projects_ids}")
    time_entries = TimeEntry.select('project_id, tmonth AS month, SUM(hours) AS total_monthly_hours').where(tyear: year).where.not(activity_id: non_billables_id).where(project_id: billable_projects_ids).group(:project_id, :tmonth).order(:project_id, :tmonth)
    
    # Convert to a dictionary of dictionaries
    time_entries_dict = time_entries.each_with_object({}) do |entry, hash|
      hash[entry.project_id] ||= {}
      hash[entry.project_id][entry.month] = entry.total_monthly_hours
    end

    time_entries_dict
  end  

  def get_invoiceable_projects()
    # Get the id of the custom field needed
    hide_project_custom_field = CustomField.find_by(name: 'Ocultar en Facturacion')
    # A value of 0 indicates that the project is NOT hidden for invoiving reports
    Project.joins('INNER JOIN custom_values cv ON cv.customized_id = projects.id').where("cv.custom_field_id = #{hide_project_custom_field.id} and cv.value = 0");
  end
end