class EntriesController < ApplicationController
  before_action :authenticate_user!
  before_filter :require_permission, only: [:show, :edit, :update, :destroy]

  def index
    begin
      if params[:photos].present?
        @entries = current_user.entries.only_images
        @title = ActionController::Base.helpers.pluralize(@entries.length,"entry")+ " with photos"
      elsif params[:year].present? && params[:month].present?
        @entries = current_user.entries.where("date >= to_date('#{params[:year]}-#{params[:month]}','YYYY-MM') AND date < to_date('#{params[:year]}-#{params[:month].to_i+1}','YYYY-MM')")
        date = Date.parse(params[:month]+'/'+params[:year])
        @title = ActionController::Base.helpers.pluralize(@entries.length,"entry")+ " from #{date.strftime('%b %Y')}"
      elsif params[:year].present?
        @entries = current_user.entries.where("date >= '#{params[:year]}-01-01'::DATE AND date <= '#{params[:year]}-12-31'::DATE")
        @title = ActionController::Base.helpers.pluralize(@entries.length,"entry")+ " from #{params[:year]}"
      elsif params[:all].present?
        @entries = current_user.entries
        @title = ActionController::Base.helpers.pluralize(@entries.length,"entry")+ " from All Time"
      else
        @entries = current_user.entries.reverse.last(30).reverse
        if @entries.length == 30
          @title = "Your latest " + ActionController::Base.helpers.pluralize(@entries.length,"entry")
        else
          @title = "Your latest entries"
        end
      end
    end
  end

  def show
    @entry = Entry.find(params[:id])
    if @entry
      render "show"
    else
      redirect_to entries_path
    end
  end

  def random
    @entry = current_user.random_entry
    if @entry
      render "show"
    else
      redirect_to entries_path
    end
  end  

  def new
    @entry = Entry.new
    @random_inspiration = random_inspiration
  end

  def create
    @user = current_user
    @existing_entry = @user.existing_entry(params[:entry][:date].to_s)

    if @existing_entry.present? && params[:entry][:entry].present?
      @existing_entry.body += "<hr>#{params[:entry][:entry]}"
      @existing_entry.inspiration_id = params[:entry][:inspiration_id] if params[:entry][:inspiration_id].present?
      if params[:entry][:image_url].present? && @existing_entry.image_url.present?
        img_url_cdn = params[:entry][:image_url].gsub("https://www.filepicker.io", ENV['FILEPICKER_CDN_HOST'])
        @existing_entry.body += "<br><div class='pictureFrame'><a href='#{img_url_cdn}' target='_blank'><img src='#{img_url_cdn}/convert?fit=max&w=300&h=300&cache=true&rotate=:exif' alt='#{@existing_entry.date.strftime("%b %-d")}'></a></div>"
      elsif params[:entry][:image_url].present?
        @existing_entry.image_url = params[:entry][:image_url]
      end
      if @existing_entry.save
        flash[:notice] = "Merged with existing entry on #{@existing_entry.date.strftime("%B %-d")}. <a href='/entries/all#entry-#{@existing_entry.id}' class='alert-link'>View merged entry</a>.".html_safe
        redirect_to entries_path
      else
        render 'new'
      end
    else
      @entry = @user.entries.create(entry_params)
      if @entry.save
        flash[:notice] = "Entry created successfully!"
        redirect_to entries_path
      else
        render 'new'
      end
    end
  end

  def edit
    store_location
    @entry = Entry.find(params[:id])
  end

  def update
    @entry = Entry.find(params[:id])
    @existing_entry = current_user.existing_entry(params[:entry][:date].to_s)

    if @existing_entry.present? && @entry != @existing_entry && params[:entry][:entry].present?
      #existing entry exists, so add to it
      @existing_entry.body += "<hr>#{params[:entry][:entry]}"
      @existing_entry.inspiration_id = params[:entry][:inspiration_id] if params[:entry][:inspiration_id].present?
      if params[:entry][:image_url].present? && @existing_entry.image_url.present?
        img_url_cdn = params[:entry][:image_url].gsub("https://www.filepicker.io", ENV['FILEPICKER_CDN_HOST'])
        @existing_entry.body += "<br><div class='pictureFrame'><a href='#{img_url_cdn}' target='_blank'><img src='#{img_url_cdn}/convert?fit=max&w=300&h=300&cache=true&rotate=:exif' alt='#{@existing_entry.date.strftime("%b %-d")}'></a></div>"        
      elsif params[:entry][:image_url].present?
        @existing_entry.image_url = params[:entry][:image_url]
      end
      if @existing_entry.save
        @entry.delete
        flash[:notice] = "Merged with existing entry on #{@existing_entry.date.strftime("%B %-d")}. <a href='#entry-#{@existing_entry.id}' class='alert-link'>View merged entry</a>.".html_safe
        redirect_back_or_to entries_path
      else
        render 'edit'        
      end
    elsif params[:entry][:entry].blank?
      @entry.destroy
      flash[:notice] = "Entry deleted!"
      redirect_back_or_to entries_path
    else
      if @entry.update(entry_params)
        flash[:notice] = "Entry successfully updated! <a href='#entry-#{@entry.id}' class='alert-link'>View entry</a>.".html_safe
        redirect_back_or_to entries_path
      else
        render 'edit'
      end
    end

  end

  def destroy
    @entry = Entry.find(params[:id])
    @entry.destroy
    flash[:notice] = "Entry deleted successfully."
    redirect_to entries_path
  end

  def export
    @entries = current_user.entries.sort_by(&:date)
     respond_to do |format|
       format.json { send_data JSON.pretty_generate(JSON.parse(@entries.to_json(:only => [:date, :body, :image_url]))), :filename => "export_#{Time.now.strftime("%Y-%m-%d")}.json" }
       format.txt do
          response.headers['Content-Type'] = 'text/txt'
          response.headers['Content-Disposition'] = "attachment; filename=export_#{Time.now.strftime("%Y-%m-%d")}.txt"
          render 'text_export'
        end
     end
  end

  private
    def entry_params
      params.require(:entry).permit(:date, :entry, :image_url, :inspiration_id)
    end

    def require_permission
      if current_user != Entry.find(params[:id]).user
        flash[:alert] = "Not authorized"
        redirect_to entries_path
      end
    end

    def random_inspiration
      if (count = Inspiration.without_ohlife_or_email.count) > 0
        Inspiration.without_ohlife_or_email.offset(rand(count)).first
      else
        nil
      end
    end
     
end
