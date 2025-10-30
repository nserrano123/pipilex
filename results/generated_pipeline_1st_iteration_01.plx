domain = "appointment_scheduling"
description = "Automated appointment scheduling via Google Calendar integration and WhatsApp voice messaging"
main_pipe = "appointment_scheduling_workflow"

[concept.Email]
description = "A valid email address identifying a person or entity."
refines = "Text"

[concept.Credentials]
description = """
Authentication information required to access a service or API, typically including tokens, keys, or OAuth data.
"""

[concept.Credentials.structure]
service_name = { type = "text", description = "The name of the service these credentials are for", required = true }
access_token = { type = "text", description = "The authentication token or key", required = true }
refresh_token = { type = "text", description = "Token used to refresh the access token" }
expiry_date = { type = "date", description = "When the credentials expire" }

[concept.CalendarQueryParameters]
description = "Parameters defining the criteria for querying calendar availability."

[concept.CalendarQueryParameters.structure]
start_date = { type = "date", description = "The beginning date for the availability search", required = true }
end_date = { type = "date", description = "The ending date for the availability search", required = true }
time_zone = { type = "text", description = "The time zone for the query", required = true }
minimum_duration_minutes = { type = "integer", description = "Minimum duration required for an appointment slot" }

[concept.TimeSlot]
description = "A specific period of time available for scheduling."

[concept.TimeSlot.structure]
start_datetime = { type = "date", description = "The start date and time of the slot", required = true }
end_datetime = { type = "date", description = "The end date and time of the slot", required = true }
time_zone = { type = "text", description = "The time zone of the slot", required = true }

[concept.AppointmentOption]
description = "A proposed appointment time with formatted details for presentation."

[concept.AppointmentOption.structure]
date = { type = "date", description = "The date of the proposed appointment", required = true }
start_time = { type = "text", description = "The start time of the appointment", required = true }
end_time = { type = "text", description = "The end time of the appointment", required = true }
time_zone = { type = "text", description = "The time zone for the appointment", required = true }
formatted_display = { type = "text", description = "Human-readable formatted version of the appointment option" }

[concept.MessageStatus]
description = "The delivery and processing status of a sent message."

[concept.MessageStatus.structure]
sent = { type = "boolean", description = "Whether the message was successfully sent", required = true }
timestamp = { type = "date", description = "When the message was sent" }
message_id = { type = "text", description = "Unique identifier for the sent message" }
error_message = { type = "text", description = "Error details if the message failed to send" }

[pipe.appointment_scheduling_workflow]
type = "PipeSequence"
description = """
Main workflow that orchestrates the complete appointment scheduling process: checks Google Calendar availability and sends WhatsApp voice message with three appointment options to the person
"""
inputs = { person_email = "Email", person_phone = "PhoneNumber", google_calendar_credentials = "Credentials", whatsapp_credentials = "Credentials" }
output = "MessageStatus"
steps = [
    { pipe = "fetch_available_slots", result = "calendar_query_parameters" },
    { pipe = "get_calendar_availability", result = "available_time_slots" },
    { pipe = "select_three_options", result = "proposed_appointment_options" },
    { pipe = "generate_appointment_message", result = "appointment_message_text" },
    { pipe = "generate_voice_script", result = "voice_script_text" },
    { pipe = "send_whatsapp_voice_message", result = "whatsapp_message_status" },
]

[pipe.fetch_available_slots]
type = "PipeLLM"
description = "Generates query parameters to search Google Calendar for available time slots over the next 7 days"
inputs = { google_calendar_credentials = "Credentials" }
output = "CalendarQueryParameters"
model = "llm_to_answer_easy_questions"
system_prompt = """
You are generating structured query parameters for a Google Calendar availability search. Output the parameters as a structured CalendarQueryParameters object.
"""
prompt = """
Generate query parameters to search for available time slots in Google Calendar over the next 7 days.

Use the provided credentials context: @google_calendar_credentials

Set the search to cover the next 7 days from today, and use an appropriate time zone based on the credentials or default to UTC. Set a reasonable minimum duration for appointment slots.
"""

[pipe.get_calendar_availability]
type = "PipeLLM"
description = "Retrieves available time slots from Google Calendar based on query parameters"
inputs = { google_calendar_credentials = "Credentials", calendar_query_parameters = "CalendarQueryParameters" }
output = "TimeSlot[]"
model = "llm_to_retrieve"
system_prompt = """
You are a calendar integration assistant that retrieves available time slots from Google Calendar. Your task is to generate structured TimeSlot objects based on the provided credentials and query parameters.
"""
prompt = """
Using the provided Google Calendar credentials and query parameters, retrieve all available time slots within the specified date range.

@google_calendar_credentials

@calendar_query_parameters

Return all available time slots that meet the minimum duration requirement.
"""

[pipe.select_three_options]
type = "PipeLLM"
description = """
Selects three optimal appointment time slots from the available slots, well-distributed across different days
"""
inputs = { available_time_slots = "TimeSlot[]" }
output = "AppointmentOption[3]"
model = "llm_to_answer_easy_questions"
system_prompt = """
You are an intelligent scheduling assistant. Your task is to analyze available time slots and select exactly three optimal appointment options that are well-distributed across different days. You will output structured AppointmentOption objects.
"""
prompt = """
From the available time slots provided below, select exactly three optimal appointment options that are well-distributed across different days to give the recipient good variety and flexibility.

@available_time_slots

Choose slots that:
- Are spread across different days when possible
- Offer good time variety (e.g., morning, afternoon, different days)
- Are convenient and reasonable appointment times

Return exactly three appointment options.
"""

[pipe.generate_appointment_message]
type = "PipeLLM"
description = "Creates a friendly, professional message proposing the three appointment options"
inputs = { person_email = "Email", proposed_appointment_options = "AppointmentOption" }
output = "Text"
model = "llm_for_creative_writing"
system_prompt = """
You are a professional assistant who writes friendly, warm, and concise messages for scheduling appointments. Your tone should be approachable yet professional.
"""
prompt = """
Create a friendly and professional message to send to $person_email proposing appointment options.

@proposed_appointment_options

The message should:
- Be warm and personable
- Clearly present the three appointment time options
- Be concise and easy to read
- Invite the recipient to choose their preferred time or suggest an alternative
"""

[pipe.generate_voice_script]
type = "PipeLLM"
description = """
Converts the appointment message into a natural, conversational voice-friendly script suitable for WhatsApp voice message
"""
inputs = { appointment_message_text = "Text" }
output = "Text"
model = "llm_for_creative_writing"
system_prompt = """
You are an expert at converting written messages into natural, conversational voice scripts. Create scripts that sound warm, friendly, and natural when spoken aloud in a voice message.
"""
prompt = """
Convert the following appointment message into a natural, conversational voice script suitable for a WhatsApp voice message.

@appointment_message_text

The script should:
- Sound natural and conversational when spoken aloud
- Be warm and friendly in tone
- Include natural pauses and transitions
- Be concise and easy to understand when heard
- Maintain the key information about the appointment options

Generate a voice-friendly script that can be directly used for recording.
"""

[pipe.send_whatsapp_voice_message]
type = "PipeLLM"
description = "Sends the voice message via WhatsApp to the person and returns delivery status"
inputs = { person_phone = "PhoneNumber", voice_script_text = "Text", proposed_appointment_options = "AppointmentOption", whatsapp_credentials = "Credentials" }
output = "MessageStatus"
model = "llm_to_answer_easy_questions"
system_prompt = """
You are a WhatsApp messaging assistant. Your task is to send a voice message via WhatsApp and return a structured MessageStatus object with the delivery status.
"""
prompt = """
Send the following voice script as a WhatsApp voice message to the phone number $person_phone:

@voice_script_text

The message includes these appointment options:
@proposed_appointment_options

Use the following WhatsApp credentials to authenticate and send the message:
@whatsapp_credentials

Send the message and return the delivery status.
"""
