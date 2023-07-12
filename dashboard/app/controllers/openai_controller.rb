class OpenaiController < ApplicationController
  # POST /openai/chat_completion
  def chat_completion
    return unless current_user.ai_chat_access?
    # Set up the API endpoint URL and request headers
    url = "https://api.openai.com/v1/chat/completions"
    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{CDO.openai_chat_api_key}"
    }
    headers["OpenAI-Organization"] = CDO.openai_org

    body = JSON.parse(request.body.read)
    # Set up the API endpoint URL and request headers
    data = {
      model: 'gpt-3.5-turbo',
      temperature: 0,
      messages: body["messages"],
    }

    # Send the request to the API endpoint
    response = HTTParty.post(url, headers: headers, body: data.to_json)

    # Parse the response JSON and return the completed text
    if response.code == 200
      response_body = JSON.parse(response.body)
      response = response_body['choices'][0]['message']
      render json: response
    else
      puts(response)
      render json: {error: "Chat completion failed: #{response.to_json}"}, status: :bad_request
    end
  end
end
