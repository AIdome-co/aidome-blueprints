# Language-Specific Vulnerability Patterns

Load the relevant section during Step 1 (Scope Resolution) after identifying languages.

---

## JavaScript / TypeScript (Node.js, React, Next.js, Express)

### Critical APIs/calls to flag
```js
eval()                    // arbitrary code execution
Function('return ...')   // same as eval
child_process.exec()     // command injection if user input reaches it
fs.readFile              // path traversal if user controls path
fs.writeFile             // path traversal if user controls path
```

### Express.js specific
```js
// Missing helmet (security headers)
const app = express()
// Should have: app.use(helmet())

// CORS misconfiguration
app.use(cors({ origin: '*' }))  // too permissive
```

### React specific
```jsx
<div dangerouslySetInnerHTML={{ __html: userContent }} />  // XSS
<a href={userUrl}>link</a>  // javascript: URL injection
```

---

## Python (Django, Flask, FastAPI)

### Django specific
```python
# Raw SQL
User.objects.raw(f"SELECT * FROM users WHERE name = '{name}'")  # SQLi

# Debug mode in production
DEBUG = True  # in settings.py — exposes stack traces

# SECRET_KEY
SECRET_KEY = 'django-insecure-...'  # must be changed for production

# ALLOWED_HOSTS
ALLOWED_HOSTS = ['*']  # too permissive
```

### Flask specific
```python
# Debug mode
app.run(debug=True)  # never in production

# render_template_string with user input (SSTI)
render_template_string(f"Hello {name}")  # Server-Side Template Injection
```

### FastAPI specific
```python
# Missing auth dependency
@app.delete("/users/{user_id}")  # No Depends(get_current_user)
async def delete_user(user_id: int):
    ...

# Arbitrary file read
@app.get("/files/{filename}")
async def read_file(filename: str):
    return FileResponse(f"uploads/{filename}")  # path traversal
```

---

## Java (Spring Boot)

### Spring Boot specific
```java
// SQL Injection
String query = "SELECT * FROM users WHERE name = '" + name + "'";
jdbcTemplate.query(query, ...);

// Spring Security — permitAll on sensitive endpoint
.antMatchers("/admin/**").permitAll()

// Actuator endpoints exposed
management.endpoints.web.exposure.include=*  # in application.properties
```

---

## Shell (Bash / sh) — Relevant for IaC Scripts

```bash
# Command injection via unquoted variables
eval "$USER_INPUT"
sh -c "$USER_INPUT"

# Insecure temp files
TMPFILE=/tmp/myfile  # predictable; use mktemp

# World-readable sensitive files
chmod 777 /etc/app/config.yaml  # never

# Unvalidated file paths
cat "$USER_INPUT_FILE"  # path traversal
```

---

## Go

```go
// Command injection
exec.Command("sh", "-c", userInput)

// SQL injection
db.Query("SELECT * FROM users WHERE name = '" + name + "'")

// Insecure TLS
http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
```

---

## Ruby on Rails

```ruby
# SQL injection (safe alternatives use placeholders)
User.where("name = '#{params[:name]}'")  # VULNERABLE
User.where("name = ?", params[:name])   # SAFE

# eval / send with user input
eval(params[:code])
send(params[:method])  # arbitrary method call

# YAML.load (allows arbitrary object creation)
YAML.load(user_input)  # use YAML.safe_load instead
```
