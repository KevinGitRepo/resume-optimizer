const API_BASE = "{{API_GATEWAY_URL}}";

async function login() {
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;

    try {
        const res = await fetch(`${API_BASE}/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });

        const { message } = await res.json();
        if (res.ok) {
            localStorage.setItem('username', username);
            alert(message);
            loadFiles();
            window.location.href = "homepage.html";
        } else {
            alert(message);
        }

    } catch (err) {
        console.error(err);
        alert('Error logging in: ' + err.message);
    }
}

async function uploadFile() {
    const file = document.getElementById('fileInput').files[0];
    const username = localStorage.getItem('username');

    if (!username) {
        alert('Please log in first!');
        return;
    }

    if (!file) {
        alert("Please select a file first!");
        return;
    }
    try {
        const res = await fetch(`${API_BASE}/upload-file/${username}/${file.name}`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({fileName: file.name, contentType: file.type})
        });

        const {url} = await res.json();

        const uploadRes = await fetch(url, {
            method: 'PUT',
            body: file,
            headers: {'Content-Type': 'application/octet-stream'}
        });

        if (!uploadRes.ok) throw new Error('File upload failed!');
        alert(`Upload successful: ${file.name}`);
        loadFiles();
    } catch (err) {
        console.error(err);
        alert('Error uploading file: ' + err.message);
    }
}

async function loadFiles() {
    const username = localStorage.getItem('username');

    if (!username) {
        alert('Please log in to view your files.');
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/list-files/${username}`);
        const { files } = await res.json();
        const list = document.getElementById('resume-select');
        if (files.length === 0 || list === null) {
            return;
        }

        files.forEach(fileName => {
            const option = document.createElement('option');
            option.textContent = fileName;
            list.appendChild(option);
        });
    } catch (err) {
        console.error(err);
        alert("Error loading files: " + err.message);
    }
}

async function loadRates() {
    const file = document.getElementById('resume-select');
    const filename = file.value;
    const username = localStorage.getItem('username');

    if (!username) {
        alert('Please log in to view your files.');
        return;
    }

    if (!filename) {
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/success-rate/${username}/${filename}`);
        const { success_rate } = await res.json();
        const rate = document.getElementById('rate');
        if (rate === null) {
            return;
        }

        rate.innerText = 'Current Success Rate = ' + success_rate
    } catch (err) {
        console.error(err);
        alert("Error loading files: " + err.message);
    }
}

async function calculateRates() {
    const file = document.getElementById('resume-select');
    const filename = file.value;
    const username = localStorage.getItem('username');
    const num = document.getElementById('sent');
    const num_success = document.getElementById('reply');

    if (!username) {
        alert('Please log in first!');
        return;
    }

    if (!file) {
        alert("Please select a file first!");
        return;
    }
    try {
        const res = await fetch(`${API_BASE}/success-rate/${username}/${filename}`, {
            method: 'PUT',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ filename: filename, username: username, num_sent: num, num_successes: num_success})
        });

        loadRates();
    } catch (err) {
        console.error(err);
        alert('Error uploading success rate: ' + err.message);
    }
}

function logout() {
    localStorage.removeItem('username');
    alert('Logged out successfully!');
    window.location.href = "index.html";
}

window.onload = () => {
    const username = localStorage.getItem('username');
    if (username) {
        loadFiles();
        loadRates();
    }
}