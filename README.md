# ⚡ SwiftHook

**SwiftHook** is a lightweight runtime hooking utility for Swift that allows developers to intercept, observe, and modify method behavior.

It provides a simple way to inject custom logic **before**, **after**, or **instead of** existing method executions.

> “Understand the system. Then bend it.”

---

## 🚀 Overview

SwiftHook is designed for developers who want more control over runtime behavior in Swift applications.

With SwiftHook you can:

* intercept method calls
* add custom logic to existing functions
* monitor execution flow
* experiment with runtime instrumentation

This makes it useful for debugging, analytics, testing, and runtime experimentation.

---

## ✨ Features

* 🔗 Hook method execution
* ⚡ Inject logic before or after functions
* 🔁 Replace method implementations
* 🧠 Runtime inspection
* 🛠 Lightweight and developer-friendly

---

## 🧩 Example

```swift
class Example {
    @objc dynamic func greet() {
        print("Hello")
    }
}

// Hook before method execution
hookBefore(object: example, selector: #selector(Example.greet)) {
    print("Before greet()")
}
```

Output:

```
Before greet()
Hello
```

---

## 🏗 Use Cases

SwiftHook can be used for:

* debugging frameworks
* runtime monitoring
* analytics instrumentation
* behavior experimentation
* advanced iOS/macOS development

---

## 📦 Installation

Clone the repository:

```bash
git clone https://github.com/krishnashahane/swifthook.git
```

Enter the project directory:

```bash
cd swifthook
```

---

## 🧠 Philosophy

Small tools.
Deep understanding.
Maximum control.

SwiftHook exists to help developers explore how runtime systems behave.

---

## 🤝 Contributing

Contributions are welcome.

1. Fork the repository
2. Create a new branch
3. Commit changes
4. Submit a pull request

---

## 📜 License

MIT License

---

## 👨‍💻 Author

Krishna
GitHub: https://github.com/krishnashahane
