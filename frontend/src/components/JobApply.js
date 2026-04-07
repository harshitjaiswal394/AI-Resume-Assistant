import React, { useState } from "react";
import axios from "axios";

const JobApply = () => {
  const [jobUrl, setJobUrl] = useState("");
  const [jd, setJd] = useState("");
  const [status, setStatus] = useState("");

  const fetchJob = async () => {
    if (!jobUrl) return alert("Enter job URL");

    setStatus("Fetching job description...");

    try {
      const res = await axios.post(
        `http://127.0.0.1:8000/job?url=${jobUrl}`
      );

      setJd(res.data.jd);
      setStatus("✅ Job loaded");
    } catch {
      setStatus("❌ Failed to fetch job");
    }
  };

  const applyJob = () => {
    if (!jobUrl) return alert("Enter job URL");

    setStatus("Opening job page...");
    window.open(jobUrl, "_blank");
  };

  return (
    <div className="card">
      <h3>💼 Apply for Job</h3>

      <input
        type="text"
        placeholder="Paste Workday Job URL here"
        value={jobUrl}
        onChange={(e) => setJobUrl(e.target.value)}
      />

      <button className="btn-secondary" onClick={fetchJob}>
        Fetch Job Description
      </button>

      <button className="btn-primary" onClick={applyJob}>
        🚀 Apply Automatically
      </button>

      <div className="status">{status}</div>

      {jd && (
        <div className="preview">
          <strong>Job Preview:</strong>
          <p>{jd}</p>
        </div>
      )}
    </div>
  );
};

export default JobApply;