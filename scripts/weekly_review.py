import os
import glob
import datetime
import yaml
import google.generativeai as genai

# Configure Gemini
api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    print("Warning: GEMINI_API_KEY not set. Skipping review generation.")
    exit(0)

genai.configure(api_key=api_key)

def parse_note(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Extract front matter
    if content.startswith('---'):
        try:
            parts = content.split('---', 2)
            if len(parts) >= 3:
                front_matter = yaml.safe_load(parts[1])
                body = parts[2]
                return front_matter, body
        except Exception as e:
            print(f"Error parsing {filepath}: {e}")
    
    return None, content

def get_recent_notes(days=7):
    notes_dir = 'notes'
    recent_notes = []
    cutoff_date = datetime.datetime.now() - datetime.timedelta(days=days)
    
    if not os.path.exists(notes_dir):
        print(f"Notes directory '{notes_dir}' does not exist.")
        return []

    for root, dirs, files in os.walk(notes_dir):
        for file in files:
            if file.endswith('.md'):
                filepath = os.path.join(root, file)
                try:
                    front_matter, body = parse_note(filepath)
                    
                    note_date = None
                    if front_matter and 'date' in front_matter:
                        try:
                            # Handle date object or string
                            d = front_matter['date']
                            if isinstance(d, datetime.date):
                                note_date = datetime.datetime(d.year, d.month, d.day)
                            else:
                                note_date = datetime.datetime.strptime(str(d), '%Y-%m-%d')
                        except:
                            pass
                    
                    # Fallback to filename date
                    if not note_date:
                        try:
                            date_str = file[:10]
                            note_date = datetime.datetime.strptime(date_str, '%Y-%m-%d')
                        except:
                            pass
                    
                    if note_date and note_date >= cutoff_date:
                        recent_notes.append({
                            'title': front_matter.get('title', file) if front_matter else file,
                            'content': body.strip(),
                            'category': front_matter.get('category', 'General') if front_matter else 'General',
                            'date': note_date
                        })
                except Exception as e:
                    print(f"Skipping file {file} due to error: {e}")
    
    return recent_notes

def generate_review(notes):
    if not notes:
        return "No notes found for this week."
    
    model = genai.GenerativeModel('gemini-1.5-flash')
    
    prompt = """
    You are a personal knowledge assistant. Review the following notes from the past week and provide a comprehensive summary.
    
    Structure the review as follows:
    1. **Executive Summary**: High-level overview of what was learned/collected this week.
    2. **Key Themes**: Group the notes by themes or categories and summarize the key insights for each.
    3. **Actionable Insights**: Identify any actionable takeaways or ideas that emerged.
    4. **Connections**: Identify any interesting connections between different notes.
    
    Here are the notes:
    """
    
    for note in notes:
        # Truncate content to avoid token limits if necessary, but keep enough context
        content_preview = note['content'][:2000] 
        prompt += f"\n---\nTitle: {note['title']}\nCategory: {note['category']}\nDate: {note['date'].strftime('%Y-%m-%d')}\nContent:\n{content_preview}\n"
        
    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return f"Error generating review: {e}"

def main():
    print("Starting weekly review...")
    recent_notes = get_recent_notes()
    print(f"Found {len(recent_notes)} notes from the last week.")
    
    if not recent_notes:
        print("No notes to review.")
        return

    review_content = generate_review(recent_notes)
    
    output_dir = 'weekly_reviews'
    os.makedirs(output_dir, exist_ok=True)
    
    date_str = datetime.datetime.now().strftime('%Y-%m-%d')
    filename = f"{output_dir}/{date_str}-Weekly-Review.md"
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(f"# Weekly Review - {date_str}\n\n")
        f.write(review_content)
        
    print(f"Review saved to {filename}")

if __name__ == "__main__":
    main()
