import React, { useState } from "react";
import axios from "axios";

const suggestions = [
  "Summarize my experience",
  "What are my key skills?",
  "How can I improve my resume?",
  "What are my top achievements",
];

const Chat = () => {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);

  const sendMessage = async (customInput) => {
    const question = customInput || input;

    if (!question.trim()) return;

    setMessages((prev) => [
      ...prev,
      { text: question, sender: "user" }
    ]);

    setInput("");
    setLoading(true);

    try {
      const res = await axios.post("/api/ask", {
        question: question
      });

      const answer = res.data?.answer || "No response";

      setMessages((prev) => [
        ...prev,
        { text: answer, sender: "bot" }
      ]);

    } catch (err) {
      setMessages((prev) => [
        ...prev,
        { text: "❌ Error getting response", sender: "bot" }
      ]);
    }

    setLoading(false);
  };

  return (
    <>
      {/* 🔥 Suggestions */}
      <div className="suggestions">
        {suggestions.map((q, index) => (
          <button
            key={index}
            className="suggestion-btn"
            onClick={() => sendMessage(q)}
          >
            {q}
          </button>
        ))}
      </div>

      {/* Chat */}
      <div className="chat-box">
        {messages.map((msg, index) => (
          <div
            key={index}
            className={`message ${msg.sender === "user" ? "user" : "bot"}`}
          >
            {msg.text}
          </div>
        ))}

        {loading && <div className="message bot">⏳ Thinking...</div>}
      </div>

      {/* Input */}
      <div className="input-box">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask about your resume..."
          onKeyDown={(e) => e.key === "Enter" && sendMessage()}
        />
        <button onClick={() => sendMessage()}>Send</button>
      </div>
    </>
  );
};

export default Chat;