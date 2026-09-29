import { Menu, Sparkles, Zap } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { checkHealth, sendChat } from "./api";
import ChatInput from "./components/ChatInput";
import MessageBubble from "./components/MessageBubble";
import Sidebar from "./components/Sidebar";

const STORAGE_KEY = "pocketsmart-chats-v1";
const suggestions = [
  "Explain a difficult topic in simple words",
  "Help me plan my day efficiently",
  "Write a professional email for me",
  "Help me build a coding project",
];

function makeChat() {
  return {id: crypto.randomUUID(), title: "New conversation", messages: [], createdAt: Date.now()};
}

export default function App() {
  const [chats, setChats] = useState(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
      return Array.isArray(saved) ? saved : [];
    } catch { return []; }
  });
  const [activeId, setActiveId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [backendOnline, setBackendOnline] = useState(false);

  useEffect(() => localStorage.setItem(STORAGE_KEY, JSON.stringify(chats)), [chats]);

  useEffect(() => {
    checkHealth().then(() => setBackendOnline(true)).catch(() => setBackendOnline(false));
  }, []);

  const activeChat = useMemo(
    () => chats.find((chat) => chat.id === activeId) || null, [chats, activeId]
  );

  function createChat() {
    const chat = makeChat();
    setChats((current) => [chat, ...current]);
    setActiveId(chat.id);
    setSidebarOpen(false);
  }

  function ensureChat() {
    if (activeChat) return activeChat;
    const chat = makeChat();
    setChats((current) => [chat, ...current]);
    setActiveId(chat.id);
    return chat;
  }

  function updateChat(id, updater) {
    setChats((current) => current.map((chat) => chat.id === id ? updater(chat) : chat));
  }

  async function handleSend(text) {
    const chat = ensureChat();
    const userMessage = {role: "user", content: text};
    const nextMessages = [...chat.messages, userMessage];

    updateChat(chat.id, (current) => ({
      ...current,
      title: current.messages.length === 0 ? (text.length > 38 ? `${text.slice(0, 38)}…` : text) : current.title,
      messages: nextMessages,
    }));

    setLoading(true);
    try {
      const answer = await sendChat(nextMessages);
      updateChat(chat.id, (current) => ({
        ...current,
        messages: [...current.messages, {role: "assistant", content: answer}],
      }));
      setBackendOnline(true);
    } catch (error) {
      updateChat(chat.id, (current) => ({
        ...current,
        messages: [...current.messages, {role: "assistant", content: `I couldn't complete that request.\n\n${error.message}`}],
      }));
      setBackendOnline(false);
    } finally {
      setLoading(false);
    }
  }

  function deleteChat(id) {
    setChats((current) => current.filter((chat) => chat.id !== id));
    if (activeId === id) setActiveId(null);
  }

  const messages = activeChat?.messages || [];

  return (
    <div className="app-shell">
      <Sidebar
        chats={chats}
        activeId={activeId}
        onNew={createChat}
        onSelect={(id) => {setActiveId(id); setSidebarOpen(false);}}
        onDelete={deleteChat}
        open={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />

      {sidebarOpen && <button className="mobile-overlay" onClick={() => setSidebarOpen(false)} aria-label="Close sidebar"/>}

      <main className="main-panel">
        <header className="topbar">
          <button className="icon-button menu-button" onClick={() => setSidebarOpen(true)}><Menu size={21}/></button>
          <div className="model-name">
            <span className="status-dot"/>PocketSmart AI<span className="model-pill">Luna</span>
          </div>
          <div className="connection">
            <span className={`connection-dot ${backendOnline ? "online" : ""}`}/>
            {backendOnline ? "Online" : "Offline"}
          </div>
        </header>

        <section className="chat-area">
          {messages.length === 0 ? (
            <div className="welcome">
              <div className="welcome-icon"><Sparkles size={29}/></div>
              <h1>What can I help you with?</h1>
              <p>Ask questions, learn something new, write content, solve problems, or build your next idea with PocketSmart AI.</p>
              <div className="suggestion-grid">
                {suggestions.map((suggestion) => (
                  <button key={suggestion} className="suggestion-card" onClick={() => handleSend(suggestion)}>
                    <Zap size={17}/><span>{suggestion}</span>
                  </button>
                ))}
              </div>
            </div>
          ) : (
            <div className="messages">
              {messages.map((message, index) => (
                <MessageBubble key={`${message.role}-${index}`} role={message.role} content={message.content}/>
              ))}
              {loading && (
                <div className="message-row assistant-row">
                  <div className="avatar bot-avatar"><Sparkles size={17}/></div>
                  <div className="message-bubble assistant-bubble typing"><span/><span/><span/></div>
                </div>
              )}
            </div>
          )}
        </section>

        <ChatInput onSend={handleSend} disabled={loading}/>
      </main>
    </div>
  );
}
