import requests
from bs4 import BeautifulSoup
import sqlite3
from urllib.parse import urljoin

# --- الإعدادات ---
START_URL = "http://books.toscrape.com/" 
MAX_PAGES = 1000
DB_NAME = "search_data.db"

# 1. إعداد قاعدة البيانات بأعمدة منفصلة
conn = sqlite3.connect(DB_NAME)
cursor = conn.cursor()
cursor.execute('DROP TABLE IF EXISTS pages')
# عملنا جدول FTS5 بـ 3 أعمدة: url, title, content
cursor.execute('CREATE VIRTUAL TABLE pages USING fts5(url, title, content)')
conn.commit()

visited = set()//visited [start url,x,y]
to_visit = [START_URL]//[z,a,b,c,o,p,l,y]
count = 0

print("🚀 Starting organized scraping...")

while to_visit and count < MAX_PAGES:
    url = to_visit.pop(0)
    if url in visited: continue

    try:
        response = requests.get(url, timeout=5)
        soup = BeautifulSoup(response.text, "html.parser")

        # --- فصل البيانات ---
        title = soup.title.string if soup.title else "No Title"
        # تنظيف المحتوى (النص فقط بدون الـ HTML)
        content = " ".join(soup.get_text().split()) 

        if len(content) < 100: continue

        # --- تخزين البيانات منفصلة ---
        cursor.execute("INSERT INTO pages (url, title, content) VALUES (?, ?, ?)", 
                       (url, title, content))
        conn.commit()

        print(f"[{count + 1}] Saved: {title}")

        visited.add(url)
        count += 1

        # جمع اللينكات
        for link in soup.find_all("a", href=True):
            full_url = urljoin(url, link['href']).split('#')[0]
            if full_url not in visited:
                to_visit.append(full_url)

    except:
        continue

conn.close()
print("✅ Done! Columns are now separate.")