class ReportController < ApplicationController
  unloadable
  before_action :require_admin

  def index
    projects = Project.all

    billing_type = CustomField.where(name: 'Tipo de Facturacion').first
    @billing_types = projects.first.available_custom_fields.select { |p| p.name == "Tipo de Facturacion" }.first.possible_values
    @billing_types.push("") unless @billing_types.include?("")
    @grouped_projects = projects.group_by { |proj| proj.custom_field_value(billing_type.id) }
    @year = params[:year]
    @previous_year = (@year.to_i - 1).to_s
    @next_year = (@year.to_i + 1).to_s
    @total_hours = Hash.new
    @hidden = Hash.new
    @non_billables_id = TimeEntryActivity.where(name: 'No-Facturables').first.id
    hide_project = CustomField.where(name: 'Ocultar en Facturacion').first

    projects.each do |proj|
      month_hours = Hash.new
      [*1..12].each do |month|
        month_hours[month] = total_hours(proj.id, month, @year)
      end
      @total_hours[proj.id] = month_hours
      @hidden[proj.id] = proj.custom_field_value(hide_project.id).to_i.nonzero?
    end
  end 
  
  private

  def project_time_entries(project_id, month, year)
    time_entries = TimeEntry.where("tmonth = ? and tyear = ? and project_id = ?",
                                   month, year, project_id).where.not("activity_id = ?", @non_billables_id)
  end

  def has_hours?(project_id, month, year)
    time_entries = project_time_entries(project_id, month, year)

    time_entries.count > 0
  end

  def total_hours(project_id, month, year)
    time_entries = project_time_entries(project_id, month, year)

    time_entries.sum(:hours).to_i
  end
end