class Core::Datatable
  include ActiveRecord::Sanitization::ClassMethods
  class MethodNotImplementedError < StandardError; end

  attr_reader :view, :options, :sortable_columns, :searchable_columns
  delegate :params, :h, :link_to, :check_box, :number_to_currency, :current_core_user, to: :@view

  #Inicializa las variables de instancia view y options
  def initialize(view, options = {})
    @view = view
    @options = options
    params.permit!
  end

  #Inicializa las sorteable_columns solo si apuntan a nil o false
  def sortable_columns
    @sortable_columns ||= []
  end

  #Inicializa las searchable_columns solo si apuntan a nil o false
  def searchable_columns
    @searchable_columns ||= []
  end

  #Metodo no implementado. Arroja un MethodNotImplementedError con un mensaje.
  def data
    fail(
      MethodNotImplementedError,
      'Please implement this method in your class.'
    )
  end

  #Metodo no implementado. Arroja un MethodNotImplementedError con un mensaje.
  def get_raw_records
    fail(
      MethodNotImplementedError,
      'Please implement this method in your class.'
    )
  end

  #Convierte los parametros que se le pasan a un JSON
  def as_json(options = {})
    {
      :draw => params[:draw].to_i,
      :recordsTotal =>  get_raw_records.count(:all),
      :recordsFiltered => filter_records(get_raw_records).count(:all),
      :data => data
    }
  end

  private

  #Inicializa la variable de entorno @records y le asigna valor cuando este apunta a nil o false.
  def records
    @records ||= fetch_records
  end

 
  #Le asigna a records los registros ordenados, filtrados y paginados
  def fetch_records
    records = get_raw_records
    records = sort_records(records) if params[:order].present?
    records = filter_records(records) if params[:search].present?
    records = paginate_records(records) unless params[:length].present? && params[:length] == '-1'
    records
  end

  #Ordena los registros que se le pasan
  def sort_records(records)
    sort_by = []
    params[:order].to_h.each_value do |item|
      sort_by << "#{sort_column(item)} #{sort_direction(item)}"
    end
    records.order(sort_by.join(", "))
  end

  #Pagina los registros que se le pasan
  def paginate_records(records)
    records.page(page).per(per_page)
  end

  #Filtra los registros que se le pasan usando simple_search y composite_search
  def filter_records(records)
    records = simple_search(records)
    records = composite_search(records)
    records
  end

  #Realiza una busqueda simple siempre y cuando haya parametros de busqueda
  def simple_search(records)
    return records unless (params[:search].present? && params[:search][:value].present?)
    conditions = build_conditions_for(params[:search][:value])
    records = records.where(conditions) if conditions
    records
  end

  #Realiza una busqueda compuesta
  def composite_search(records)
    conditions = aggregate_query
    records = records.where(conditions) if conditions
    records
  end

  #
  def build_conditions_for(query)
    search_for = query.split(' ')
    criteria = search_for.inject([]) do |criteria, atom|
      criteria << searchable_columns.map { |col| search_condition(col, atom) }.reduce(:or)
    end.reduce(:and)
    criteria
  end

  def search_condition(column, value)
    if column[0] == column.downcase[0]
      return deprecated_search_condition(column, value)
    else
      return new_search_condition(column, value)
    end
  end

  def new_search_condition(column, value)
    model, column = column.split('.')
    model = model.constantize
    casted_column = ::Arel::Nodes::NamedFunction.new('CAST', [model.arel_table[column.to_sym].as(typecast)])
    casted_column.matches("%#{sanitize_sql_like(value)}%")
  end

  def deprecated_search_condition(column, value)
    model, column = column.split('.')
    model = model.singularize.titleize.gsub( / /, '' ).constantize

    casted_column = ::Arel::Nodes::NamedFunction.new('CAST', [model.arel_table[column.to_sym].as(typecast)])
    casted_column.matches("%#{sanitize_sql_like(value)}%")
  end

  def aggregate_query
    conditions = searchable_columns.each_with_index.map do |column, index|
      if params[:columns]
        if params[:columns]["#{index}"]
          value = params[:columns]["#{index}"][:search][:value] if params[:columns]["#{index}"][:search]
        end
      end
      search_condition(column, value) unless value.blank?
    end
    conditions.compact.reduce(:and)
  end

  def typecast
    'TEXT'
  end

  def offset
    (page - 1) * per_page
  end

  def page
    (params[:start].to_i / per_page) + 1
  end

  def per_page
    params.fetch(:length, 10).to_i
  end

  def sort_column(item)
    new_sort_column(item)
  end

  def deprecated_sort_column(item)
    sortable_columns[sortable_displayed_columns.index(item[:column])]
  end

  def new_sort_column(item)
    model, column = sortable_columns[sortable_displayed_columns.index(item[:column])].split('.')
    col = [model.constantize.table_name, column].join('.')
  end

  def sort_direction(item)
    options = %w(desc asc)
    options.include?(item[:dir]) ? item[:dir].upcase : 'ASC'
  end

  def sortable_displayed_columns
    @sortable_displayed_columns ||= generate_sortable_displayed_columns
  end

  def generate_sortable_displayed_columns
    @sortable_displayed_columns = []
    params[:columns].to_h.each_value do |column|
      @sortable_displayed_columns << column[:data] if column[:orderable] == 'true'
    end
    @sortable_displayed_columns
  end

end
