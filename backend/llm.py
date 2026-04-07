import os
from openai import OpenAI
from dotenv import load_dotenv
import time
load_dotenv()

#  Initialize NVIDIA client
client = OpenAI(
    base_url="https://integrate.api.nvidia.com/v1",
    api_key=os.getenv("NVIDIA_API_KEY")  #  replace this
)

def ask_llm(question, resume_text):
    if not question.strip():
        return " Question cannot be empty. Please provide a valid question."

    if not resume_text.strip():
        return " Resume content is missing. Please upload your resume first."

    for attempt in range(3):  # Retry up to 3 times
        try:
            print(f" Attempt {attempt + 1}: Calling LLM...")

            prompt = f"""
    You are a professional job assistant.

    STRICT RULES:
    - Answer MUST be Accurate and complete based on the resume
    - Do NOT cut sentences midway
    - Minimum 3 lines, maximum 5 lines
    - No markdown
    - Start with "You have"
    - Be consistent and structured
    - Focus on skills, experience, and impact

    Candidate Resume:
    {resume_text}

    Question:
    {question}

    Answer clearly and professionally.
    """

            response = client.chat.completions.create(
                model="nvidia/nvidia-nemotron-nano-9b-v2",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                top_p=0.9,
                max_tokens=600
            )

            answer = response.choices[0].message.content

            if not answer or len(answer.strip()) < 12:
                print(" Incomplete response from LLM. Retrying...")
                time.sleep(2 ** attempt)  # Exponential backoff
                continue

            return answer.strip()

        except Exception as e:
            print(f" LLM Error on attempt {attempt + 1}: {str(e)}")
            time.sleep(2 ** attempt)  # Exponential backoff

    return " Unable to generate a response after multiple attempts. Please try again later."

def ask_llm_with_history(history, resume_text):
    if not history:
        return " Chat history is empty. Please provide valid inputs."

    if not resume_text.strip():
        return " Resume content is missing. Please upload your resume first."

    try:
        messages = [
            {
                "role": "system",
                "content": f"Candidate Resume:\n{resume_text}"
            }
        ] + history

        response = client.chat.completions.create(
            model="nvidia/nvidia-nemotron-nano-9b-v2",
            messages=messages,
            temperature=0.2,
            top_p=0.9,
            max_tokens=600
        )

        answer = response.choices[0].message.content

        if not answer or len(answer.strip()) < 12:
            return " Unable to generate a response. Please try again later."

        return answer.strip()

    except Exception as e:
        print(" LLM Error:", str(e))
        return " Unable to generate a response due to an error. Please try again later."