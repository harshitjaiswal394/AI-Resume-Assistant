import React from "react";
import ResumeUpload from "./components/ResumeUpload";
import Chat from "./components/Chat";
import "./styles.css";

function App() {
  return (
    <div className="container">
      <div className="header">🚀 Resume AI Assistant</div>

      <ResumeUpload />
      <Chat />
    </div>
  );
}

export default App;