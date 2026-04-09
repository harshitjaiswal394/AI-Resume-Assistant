import React, { useState } from "react";
import axios from "axios";

const ResumeUpload = () => {
  const [file, setFile] = useState(null);
  const [status, setStatus] = useState("");

  const uploadResume = async () => {
    if (!file) return alert("Please upload a resume");

    setStatus("Uploading...");

    const formData = new FormData();
    formData.append("file", file);

    try {
      await axios.post("/api/upload-resume", formData, {
        headers: { "Content-Type": "multipart/form-data" }
      });

      setStatus("✅ Resume uploaded successfully!");
    } catch (e) {
      setStatus("❌ Upload failed");
    }
  };

  return (
    <div className="card">
      <h3>📄 Upload Resume</h3>

      <input
        type="file"
        onChange={(e) => setFile(e.target.files[0])}
      />

      <button className="btn-primary" onClick={uploadResume}>
        Upload Resume
      </button>

      <div className="status">{status}</div>
    </div>
  );
};

export default ResumeUpload;