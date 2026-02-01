# **NYC Airbnb Data Cleaning & Validation (SQL)**

## **Overview**

This project focuses on **data cleaning and data quality validation** using a real-world Airbnb dataset.

The goal is to demonstrate how raw CSV data can be:

* loaded into PostgreSQL
* validated with SQL checks
* cleaned step by step
* prepared for further BI or analytics work

The project is intentionally **SQL-first** and does not include dashboards.

## **Dataset**

**Source:**

NYC Airbnb Open Data (Kaggle)

The dataset contains listings data for Airbnb properties, including:

* listing identifiers
* prices
* room and property types
* availability
* geographic information
* host and review metrics

Only a **sample CSV file** is stored in this repository.

The full dataset can be downloaded from Kaggle.

## **Tools & Environment**

* PostgreSQL (local)
* psql
* SQL
* VS Code
* GitHub

## **Project Structure**

## sql-data-cleaning/

├── data/
│   └── listings.csv
│
├── sql/
│   ├── 01_raw_schema.sql
│   ├── 02_data_quality_checks.sql
│   ├── 03_cleaning_steps.sql
│   └── 04_clean_table.sql
│
└── README.md

## **Workflow**

### **1. Create Raw Table**

A raw table is created using **01_raw_schema.sql**.

Key design choice:

* All fields are loaded **as-is**
* **price** is stored as **TEXT** to avoid load errors from currency symbols

This allows transparent validation before transformations.

### **2. Load CSV Data**

Data is loaded using **\copy** from psql:

\copy airbnb_listings_raw
FROM 'data/listings.csv'
WITH (FORMAT csv, HEADER true, QUOTE '"');

### **3. Data Quality Checks**

Initial validation checks are performed in **02_data_quality_checks.sql**.

Checks include:

* row counts
* missing values in key fields
* invalid or empty prices
* geographic inconsistencies
* category distributions

This step helps identify issues **before cleaning**.

### **4. Cleaning Steps**

Cleaning logic is implemented in **03_cleaning_steps.sql**.

Examples:

* normalising price values
* removing invalid records
* handling missing or inconsistent categories
* filtering unrealistic numeric values

Each step is written explicitly to keep transformations clear and auditable.

### **5. Create Clean Table**

The final cleaned dataset is created in **04_clean_table.sql**.

The clean table:

* contains validated, consistent data
* is ready for analysis or BI reporting
* can be reused by other analysts without re-cleaning

## **Data Quality Logic (Plain Explanation)**

The following checks are applied:

1. **ID checks**
   Ensure unique identifiers exist to avoid double counting.
2. **Completeness**
   Verify that critical fields (location, room type, price) are present.
3. **Geographic validity**
   Detect missing or incorrect latitude/longitude values.
4. **Price validation**
   Identify:
   * empty prices
   * non-numeric values
   * extreme values (0 or unrealistically high)
5. **Availability & nights**
   Catch logical inconsistencies that can break metrics.
6. **Category consistency**
   Review distributions of **room_type** and **property_type**.
7. **Host metrics**
   Validate percentage-based fields and ranges.
8. **Review scores**
   Detect values outside expected bounds.
9. **Summary checks**
   Produce a small validation summary for documentation.

## **Outcome**

As a result:

* raw CSV data is safely loaded into PostgreSQL
* data issues are identified and documented
* a clean, reliable table is produced
* the dataset is ready for analytics or BI use

## **What This Project Demonstrates**

* SQL-based data cleaning
* Real-world data quality issues
* Structured validation logic
* Clear separation between raw and clean data
* Practical analytics workflow used by data teams
