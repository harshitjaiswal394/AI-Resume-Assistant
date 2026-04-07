import os
from openai import OpenAI
from dotenv import load_dotenv
load_dotenv()

# ✅ Initialize NVIDIA client
client = OpenAI(
    base_url="https://integrate.api.nvidia.com/v1",
    api_key=os.getenv("NVIDIA_API_KEY")  # 🔥 replace this
)

def ask_llm(question, resume_text):
    for attempt in range(2):  # retry once
        try:
            print("🚀 Calling LLM...")

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
                return "⚠️ LLM returned incomplete response. Please retry."

            return answer.strip()

        except Exception as e:
            print("❌ LLM Error:", str(e))
            return f"LLM Error: {str(e)}"