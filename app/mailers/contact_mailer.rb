class ContactMailer < ApplicationMailer
  default from: "noreply@aileadgen.com"

  def new_inquiry(contact_form)
    @contact_form = contact_form

    mail(
      to: "support@aileadgen.com",
      subject: "New Contact Form Inquiry - #{@contact_form.inquiry_type.humanize}",
      reply_to: @contact_form.email
    )
  end
end
