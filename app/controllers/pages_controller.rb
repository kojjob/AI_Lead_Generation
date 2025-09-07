class PagesController < ApplicationController
  # skip_before_action :authenticate_user!, only: [:about, :contact, :submit_contact]

  def about
    @team_members = [
      {
        name: "Sarah Johnson",
        role: "CEO & Founder",
        bio: "15+ years in AI and machine learning. Former tech lead at major Silicon Valley companies.",
        image: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=400&fit=crop"
      },
      {
        name: "Michael Chen",
        role: "CTO",
        bio: "Expert in scalable systems and AI infrastructure. PhD in Computer Science from MIT.",
        image: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop"
      },
      {
        name: "Emily Rodriguez",
        role: "Head of Product",
        bio: "Product visionary with a track record of building user-loved B2B SaaS products.",
        image: "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&h=400&fit=crop"
      },
      {
        name: "David Kim",
        role: "Head of Engineering",
        bio: "Full-stack engineer passionate about creating elegant solutions to complex problems.",
        image: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop"
      }
    ]

    @company_values = [
      {
        icon: "lightbulb",
        title: "Innovation",
        description: "We push boundaries and embrace new technologies to solve old problems in revolutionary ways."
      },
      {
        icon: "users",
        title: "Customer First",
        description: "Every decision we make starts with our customers' success and satisfaction in mind."
      },
      {
        icon: "shield",
        title: "Trust & Security",
        description: "We handle your data with the utmost care and maintain the highest security standards."
      },
      {
        icon: "chart",
        title: "Results Driven",
        description: "We measure our success by the tangible results we deliver for our customers."
      }
    ]

    @milestones = [
      { year: "2021", title: "Company Founded", description: "Started with a vision to revolutionize lead generation through AI" },
      { year: "2022", title: "First 100 Customers", description: "Reached our first major milestone with rapid customer adoption" },
      { year: "2023", title: "Series A Funding", description: "Secured $10M in funding to accelerate product development" },
      { year: "2024", title: "Global Expansion", description: "Expanded operations to serve customers in 30+ countries" }
    ]
  end

  def contact
    @contact_info = {
      email: "hello@aileadgen.com",
      phone: "+1 (555) 123-4567",
      address: "123 Innovation Drive, Suite 400<br>San Francisco, CA 94107",
      hours: "Monday - Friday: 9:00 AM - 6:00 PM PST"
    }

    @inquiry_types = [
      [ "General Inquiry", "general" ],
      [ "Sales & Pricing", "sales" ],
      [ "Technical Support", "support" ],
      [ "Partnership Opportunities", "partnership" ],
      [ "Media & Press", "media" ],
      [ "Other", "other" ]
    ]
  end

  def submit_contact
    @contact_form = ContactForm.new(contact_params)

    if @contact_form.valid?
      # Send email notification
      ContactMailer.new_inquiry(@contact_form).deliver_later

      respond_to do |format|
        format.html { redirect_to contact_path, notice: "Thank you for your message! We'll get back to you within 24 hours." }
        format.json { render json: { success: true, message: "Message sent successfully!" } }
      end
    else
      respond_to do |format|
        format.html {
          @contact_info = {
            email: "hello@aileadgen.com",
            phone: "+1 (555) 123-4567",
            address: "123 Innovation Drive, Suite 400<br>San Francisco, CA 94107",
            hours: "Monday - Friday: 9:00 AM - 6:00 PM PST"
          }
          @inquiry_types = [
            [ "General Inquiry", "general" ],
            [ "Sales & Pricing", "sales" ],
            [ "Technical Support", "support" ],
            [ "Partnership Opportunities", "partnership" ],
            [ "Media & Press", "media" ],
            [ "Other", "other" ]
          ]
          render :contact, status: :unprocessable_entity
        }
        format.json { render json: { success: false, errors: @contact_form.errors } }
      end
    end
  end

  private

  def contact_params
    params.require(:contact_form).permit(:name, :email, :phone, :company, :inquiry_type, :message)
  end
end

# Form object for contact form validation
class ContactForm
  include ActiveModel::Model

  attr_accessor :name, :email, :phone, :company, :inquiry_type, :message

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, allow_blank: true, format: { with: /\A[\d\s\-\+\(\)]+\z/, message: "must be a valid phone number" }
  validates :company, length: { maximum: 100 }
  validates :inquiry_type, presence: true, inclusion: { in: %w[general sales support partnership media other] }
  validates :message, presence: true, length: { minimum: 10, maximum: 1000 }
end
