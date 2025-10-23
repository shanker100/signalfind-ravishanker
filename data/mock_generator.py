import csv
import random
import faker
import argparse

# Initialize Faker
fake = faker.Faker()

# Sample skills and job titles for variation
SKILLS = [
    "python", "aws", "docker", "terraform", "sql", "java",
    "linux", "kubernetes", "react", "machine learning",
    "data engineering", "security", "devops"
]

TITLES = [
    "Software Engineer", "Data Engineer", "DevOps Engineer", "Cloud Architect",
    "Data Analyst", "ML Engineer", "Network Engineer", "Site Reliability Engineer"
]

COMPANIES = [
    "SignalFind", "TechNova", "DataCloud", "InfoZen", "NetCore", "SmartOps",
    "InnovateX", "SkyLabs", "CloudMinds", "PrimeData"
]

LOCATIONS = [
    "Sydney", "Melbourne", "Brisbane", "Adelaide", "Perth", "Canberra",
    "Auckland", "Singapore", "London", "New York"
]


def generate_mock_records(n: int):
    """Generate n mock people/company records."""
    records = []
    for _ in range(n):
        name = fake.name()
        company = random.choice(COMPANIES)
        title = random.choice(TITLES)
        email = fake.email()
        phone = fake.phone_number()
        skills = ", ".join(random.sample(SKILLS, k=random.randint(2, 5)))
        location = random.choice(LOCATIONS)

        record = {
            "name": name,
            "company": company,
            "title": title,
            "email": email,
            "phone": phone,
            "skills": skills,
            "location": location
        }
        records.append(record)
    return records


def save_to_csv(records, output_file):
    """Save mock data to a CSV file."""
    fieldnames = ["name", "company", "title", "email", "phone", "skills", "location"]
    with open(output_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)
    print(f" Mock dataset written to: {output_file} ({len(records)} records)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate mock SignalFind dataset.")
    parser.add_argument("--count", type=int, default=100, help="Number of records to generate")
    parser.add_argument("--output", type=str, default="mock_data.csv", help="Output CSV file path")
    args = parser.parse_args()

    mock_records = generate_mock_records(args.count)
    save_to_csv(mock_records, args.output)
