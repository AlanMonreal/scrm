class Crm::LeadsController < ApplicationController
  before_action :set_lead, only:[:clone, :convert, :edit, :show, :update, :destroy]

  def home
    @recent_leads = Crm::Lead.recent
  end

  def clone
    authorize @lead
    @new_lead = @lead.clone_with_associations
    if @new_lead.valid?
      @new_lead.save
      redirect_to crm_lead_path(@new_lead)
    else
      render :new
    end
  end

  def convert
    @account = Crm::Account.new(
      name: @lead.company,
      industry: @lead.industry,
      rating: @lead.rating,
      website: @lead.website,
      description: @lead.description,
      phone: @lead.person.phone,
      extension: @lead.person.extension,
      created_by: current_user,
    )
    @contact = @account.contacts.build(created_by: current_user)
    @contact.build_person(@lead.person.dup.attributes)

    if @account.valid?
      @account.save
      redirect_to :back
    end
  end

  def index
    respond_to do |format|
      format.html
      format.json { render json: Crm::LeadDatatable.new(view_context) }
    end
  end

  def new
    @lead = Crm::Lead.new
    @lead.build_person
    @lead.addresses.build
    authorize @lead
  end

  def show
    authorize @lead
    @tasks = @lead.tasks.includes(:assigned_to).page(params[:task_page]).per(5)
    @events = @lead.events.includes(:assigned_to).page(params[:event_page]).per(5)
    @notes = @lead.notes.page(params[:note_page]).per(5)
  end

  def edit
    authorize @lead
  end

  def create
    @lead = Crm::Lead.new(lead_params)
    @lead.created_by = current_user
    authorize @lead
    if @lead.valid?
      @lead.save
      redirect_to crm_leads_path
    else
      render :new
    end
  end

  def update
    authorize @lead
    if @lead.update_attributes(lead_params)
      redirect_to crm_lead_path(@lead)
    else
      render :edit
    end
  end

  def destroy
    authorize @lead
    @lead.destroy
    redirect_to crm_home_leads_path
  end

  private
  def set_lead
    @lead = Crm::Lead.includes(:person, :created_by).friendly.find(params[:id])
  end

  def lead_params
    params.require(:lead).permit(
      :id, :source, :company, :industry, :sic_code, :status,
      :website, :rating, :description, :created_by_id,
      person_attributes:
        [:_destroy, :id, :title, :first_name, :last_name, :phone, :home_phone,
          :other_phone, :email, :assistant, :asst_phone, :extension, :mobile,
          :birthdate
        ]
    )
  end
end
