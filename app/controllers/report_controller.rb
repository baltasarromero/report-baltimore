class ReportController < ApplicationController
  unloadable
  before_filter :require_admin

  def index
    billing_type = CustomField.where(name: 'Tipo de Facturacion').first
    projects = Project.all
    @billing_types = projects.first.available_custom_fields.select { |p| p.name == "Tipo de Facturacion" }.first.possible_values
    @billing_types.push("") unless @billing_types.include?("")
    @grouped_projects = projects.group_by { |proj| proj.custom_field_value(billing_type.id) }

    @year = params[:year]
    @previous_year = (@year.to_i - 1).to_s
    @next_year = (@year.to_i + 1).to_s
    @project_hours = Hash.new
    @total_hours = Hash.new
    @hidden = Hash.new

    hide_project = CustomField.where(name: 'Ocultar en Facturación').first
    projects.each do |proj|
      hours = Hash.new
      month_hours = Hash.new
      # how to iterate from 1 to 12 in ruby?
      [*1..12].each do |month|
        if has_hours?(proj.id, month, @year)
          hours[month] = true
          month_hours[month] = total_hours(proj.id, month, @year)
        end
      end
      @project_hours[proj.id] = hours

      @total_hours[proj.id] = month_hours

      @hidden[proj.id] = proj.custom_field_value(hide_project.id).to_i.nonzero?
    end
  end

  private
  def has_hours?(project_id, month, year)
    # Has hours 
    time_entries = TimeEntry.where("tmonth = ? and tyear = ? and project_id = ? and (hours > 0 or (comments is not null and comments != ''))",
                                 month, year, project_id)
    time_entries.count > 0
  end

  def total_hours(project_id, month, year)
    time_entries = TimeEntry.where("tmonth = ? and tyear = ? and project_id = ? and (hours > 0 or (comments is not null and comments != ''))",
                                   month, year, project_id)
    time_entries.sum(:hours).to_i
  end
end
