import logo from './logo.svg';
import './App.css';
import React, { useState, useEffect } from "react";

function App() {
  const [apiResult, setApiResult] = useState(null);
  useEffect(() => {
    fetch("/api/hello", {
      method: "GET",
    })
      .then((response) => response.text())
      .then((data) => {
        setApiResult(data);
        console.log(data);
      })
      .catch((error) => console.log(error));
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <h1 id="title-text">Google Cloud React test app</h1>
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          Anything is possible at this URL. The backend says:
          <pre>
            {apiResult}
          </pre>
        </p>
      </header>
    </div>
  );
}

export default App;
