# frozen_string_literal: true

class VaccinationProgramsController < ApplicationController
  def index
    @vaccination_programs = current_user.vaccination_programs
    if @vaccination_programs
      render json: { vaccinationPrograms: @vaccination_programs }
    else
      render json: { status: 500, errors: ['no programs found'] }
    end
  end

  def show
    @vaccination_program = VaccinationProgram.find(params[:id])
    signed_public_url = signed_public_url_for_today(params[:id])
    puts signed_public_url
    if @vaccination_program && @vaccination_program.user_id == current_user.id
      render json: { vaccinationProgram: @vaccination_program, signedPublicURL: signed_public_url }
    else
      render json: { status: 500, errors: ['program not found'] }
    end
  end

  def create
    @vaccination_program = VaccinationProgram.new(vaccination_program_params)
    @vaccination_program.user_id = current_user.id
    if @vaccination_program.save
      render json: { status: :created, vaccinationProgram: @vaccination_program }
    else
      render json: { status: 500, errors: @vaccination_program.errors.full_messages }
    end
  end

  def update
    @vaccination_program = VaccinationProgram.find(params[:id])
    if @vaccination_program.user_id == current_user.id && @vaccination_program.update(vaccination_program_params)
      render json: { vaccinationProgram: @vaccination_program }
    else
      render json: { status: 500, errors: ['program not found'] }
    end
  end

  def verify
    # can be run logged off.
    @vaccination_program = VaccinationProgram.find(params[:id])
    verified = verify_public_url_for_today(params[:id], params[:signature], @vaccination_program.user)
    if verified
      render json: { verified: verified, vaccinationProgram: @vaccination_program }
    else
      render json: { verified: verified }
    end
  end

  def certify
    # can be run logged off.
    @vaccination_program = VaccinationProgram.find(params[:id])
    verified = verify_public_url_for_today(params[:id], CGI::unescape(params[:certificate][:program_signature]), @vaccination_program.user)
    if verified
      cert = signed_public_certificate(@vaccination_program, params[:certificate][:vaccinee], @vaccination_program.user)
      render json: { verified: verified, certificate: cert }
    else
      render json: { status: 500, verified: verified, errors: ['cannot certify this record']}
    end
  end

  private

  def certificate_url(vac_prog, vaccinee)
    'healthpass:vaccine' \
      "?name=#{CGI::escape(vac_prog.product || '')}" \
      "&vaccinator=#{CGI::escape(vac_prog.vaccinator || '')}" \
      "&date=#{Time.now.strftime('%Y-%m-%d')}" \
      "&manuf=#{CGI::escape(vac_prog.brand || '')}" \
      "&route=#{CGI::escape(vac_prog.route || '')}" \
      "&lot=#{CGI::escape(vac_prog&.lot || '')}" \
      "&dose=#{CGI::escape(vac_prog.dose || '')}" \
      "&vaccinee=#{CGI::escape(vaccinee || '')}"
  end

  def signed_public_certificate(vac_prog, vaccinee, user)
    message = certificate_url(vac_prog, vaccinee)
    private_key = OpenSSL::PKey::RSA.new(user.private_key)
    signature = private_key.sign(OpenSSL::Digest.new('SHA256'), message)
    base64_escaped_signature = CGI::escape(Base64.encode64(signature))
    "#{message}&signature=#{base64_escaped_signature}"
  end

  def generate_certificate_url(id)
    ui_url = Rails.env.production? ? 'http://healthpassport.vitorpamplona.com' : 'http://localhost:3001'
    "#{ui_url}/generateCertificate/#{id}?date=#{Time.now.strftime('%Y-%m-%d')}"
  end

  def signed_public_url_for_today(id)
    message = generate_certificate_url(id)
    private_key = OpenSSL::PKey::RSA.new(current_user.private_key)
    signature = private_key.sign(OpenSSL::Digest.new('SHA256'), message)
    base64_escaped_signature = CGI::escape(Base64.encode64(signature))
    "#{message}&signature=#{base64_escaped_signature}"
  end

  def verify_public_url_for_today(id, signature, user)
    message = generate_certificate_url(id)
    public_key = OpenSSL::PKey::RSA.new(user.public_key)
    public_key.verify(OpenSSL::Digest.new('SHA256'), Base64.decode64(signature), message)
  end

  def vaccination_program_params
    params.require(:vaccinationProgram).permit(:vaccinator, :brand, :product, :lot, :dose, :route, :signature)
  end
end
