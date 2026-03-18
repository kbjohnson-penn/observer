import mysql.connector
import os


def _parse_columns_tuple(columns_sql: str) -> list[str]:
    """
    Convert "(a, b, c)" -> ["a","b","c"]
    If columns_sql is empty/falsey, returns [].
    """
    if not columns_sql or not columns_sql.strip():
        return []
    s = columns_sql.strip()
    if s.startswith("(") and s.endswith(")"):
        s = s[1:-1]
    return [c.strip() for c in s.split(",") if c.strip()]


def load_csv_to_mariadb(base_path, host, user, password, database):
    CONVERSIONS: dict[str, dict[str, str]] = {
        "visit_occurrence": {
            "visit_start_date": "date",
            "visit_start_time": "time",
        },
        "drug_exposure": {
            "drug_ordering_date": "date",
            "drug_exposure_start_datetime": "datetime",
            "drug_exposure_end_datetime": "datetime",
        },
        "observation": {
            "observation_date": "date",
        },
        "labs": {
            "ordering_date_shifted": "datetime",
        },
    }


    def sql_expr_date(var_name: str) -> str:
        # Handles: '', 'NULL', '2024-01-01', and strips CR
        return (
            "CASE "
            f"WHEN {var_name} IS NULL OR TRIM(REPLACE({var_name}, '\\r', '')) IN ('', 'NULL') THEN NULL "
            f"WHEN {var_name} LIKE '%/%' THEN STR_TO_DATE({var_name}, '%m/%d/%Y') "
            f"ELSE STR_TO_DATE({var_name}, '%Y-%m-%d') "
            "END"
        )
    

    def sql_expr_time(var_name: str) -> str:
        # Handles: '', 'NULL', '12:34:56'
        return (
            f"NULLIF("
            f"STR_TO_DATE(NULLIF(TRIM(REPLACE({var_name}, '\\r', '')), ''), '%H:%i:%s'),"
            f" '00:00:00')"
        )
    

    def sql_expr_datetime(var_name: str) -> str:
        # Handles common forms
        # Strips trailing Z, replaces T with space, strips CR, trims
        cleaned = (
            f"TRIM(REPLACE(REPLACE(REPLACE({var_name}, '\\r', ''), 'T', ' '), 'Z', ''))"
        )
        # If it has a '.', parse with microseconds; otherwise parse normally
        return (
            "CASE "
            f"WHEN {var_name} IS NULL OR TRIM(REPLACE({var_name}, '\\r', '')) IN ('', 'NULL') THEN NULL "
            f"WHEN INSTR({cleaned}, '.') > 0 THEN STR_TO_DATE({cleaned}, '%Y-%m-%d %H:%i:%s.%f') "
            f"ELSE STR_TO_DATE({cleaned}, '%Y-%m-%d %H:%i:%s') "
            "END"
        )
    

    def build_load_query(table_config: dict) -> str:
        table = table_config["table"]
        file_path = os.path.join(base_path, table_config["file"]).replace("\\", "\\\\")
        cols = _parse_columns_tuple(table_config.get("columns", ""))

        conv_map = CONVERSIONS.get(table, {})

        if not cols:
            return f"""
                LOAD DATA LOCAL INFILE '{file_path}'
                INTO TABLE {table}
                FIELDS TERMINATED BY ','
                ENCLOSED BY '"'
                LINES TERMINATED BY '\\n'
                IGNORE 1 ROWS
            """

        # Build column list for LOAD DATA: replace convertible columns with @vars
        load_cols = []
        set_clauses = []

        for c in cols:
            if c in conv_map:
                load_cols.append(f"@{c}")
            else:
                load_cols.append(c)

        # Build SET conversions
        for c, ctype in conv_map.items():
            var = f"@{c}"
            if ctype == "date":
                set_clauses.append(f"{c} = {sql_expr_date(var)}")
            elif ctype == "time":
                set_clauses.append(f"{c} = {sql_expr_time(var)}")
            elif ctype == "datetime":
                set_clauses.append(f"{c} = {sql_expr_datetime(var)}")
            else:
                raise ValueError(f"Unsupported conversion type '{ctype}' for {table}.{c}")

        columns_sql = "(" + ", ".join(load_cols) + ")"
        set_sql = ""
        if set_clauses:
            set_sql = "\nSET " + ",\n    ".join(set_clauses)

        return f"""
            LOAD DATA LOCAL INFILE '{file_path}'
            INTO TABLE {table}
            FIELDS TERMINATED BY ','
            ENCLOSED BY '"'
            LINES TERMINATED BY '\\n'
            IGNORE 1 ROWS
            {columns_sql}
            {set_sql}
        """

    conn = None
    cursor = None
    try:
        conn = mysql.connector.connect(
            host=host,
            user=user,
            password=password,
            database=database,
            allow_local_infile=True,
            charset="utf8mb4",
            collation="utf8mb4_unicode_ci",
        )
        cursor = conn.cursor()
        print("Connected to the database successfully.")

        tables = [
            {"table": "concept", "file": "concept.csv", "columns": ""},
            {"table": "provider", "file": "provider.csv", "columns": ""},
            {"table": "person", "file": "person.csv", "columns": ""},
            {
                "table": "visit_occurrence",
                "file": "visit_occurrence.csv",
                "columns": "(id, person_id, provider_id, visit_start_date, visit_start_time, visit_source_value, visit_source_id, tier_level, department)",
            },
            {
                "table": "note",
                "file": "note.csv",
                "columns": "(id, person_id, provider_id, visit_occurrence_id, note_date, note_text, note_type, note_status)",
            },
            {
                "table": "condition_occurrence",
                "file": "condition_occurrence.csv",
                "columns": "(id, visit_occurrence_id, is_primary_dx, condition_source_value, condition_concept_id, concept_code)",
            },
            {
                "table": "drug_exposure",
                "file": "drug_exposure.csv",
                "columns": "(id, visit_occurrence_id, drug_ordering_date, drug_exposure_start_datetime, drug_exposure_end_datetime, description, quantity)",
            },
            {
                "table": "procedure_occurrence",
                "file": "procedure_occurrence.csv",
                "columns": "(id, visit_occurrence_id, procedure_ordering_date, name, description, future_or_stand)",
            },
            {
                "table": "observation",
                "file": "observation.csv",
                "columns": "(id, visit_occurrence_id, file_type, file_path, observation_date)",
            },
            {
                "table": "measurement",
                "file": "measurement.csv",
                "columns": "(id, visit_occurrence_id, bp_systolic, bp_diastolic, phys_bp, weight_lb, height, pulse, phys_spo2)",
            },
            {
                "table": "audit_logs",
                "file": "audit_logs.csv",
                "columns": "(id, visit_occurrence_id, access_time, user_id, workstation_id, access_action, metric_id, metric_name, metric_desc, metric_type, metric_group, event_action_type, event_action_subtype)",
            },
            {
                "table": "patient_survey",
                "file": "patient_survey.csv",
                "columns": "(id, form_1_timestamp, visit_date, patient_overall_health, patient_mental_emotional_health, patient_age, patient_education, overall_satisfaction_scale_1, overall_satisfaction_scale_2, tech_experience_1, tech_experience_2, relationship_with_provider_1, relationship_with_provider_2, hawthorne_1, hawthorne_2, hawthorne_3, hawthorne_4, visit_related_1, visit_related_2, visit_related_3, visit_related_4, visit_related_5, visit_related_6, hawthorne_5, open_ended_interaction, open_ended_change, open_ended_experience, visit_occurrence_id)",
            },
            {
                "table": "provider_survey",
                "file": "provider_survey.csv",
                "columns": "(id, form_1_timestamp, visit_date, years_hcp_experience, tech_experience, communication_method_1, communication_method_2, communication_method_3, communication_method_4, communication_method_5, communication_other, inbasket_messages, overall_satisfaction_scale_1, overall_satisfaction_scale_2, patient_related_1, patient_related_2, patient_related_3, visit_related_1, visit_related_2, visit_related_4, hawthorne_1, hawthorne_2, hawthorne_3, open_ended_1, open_ended_2, visit_occurrence_id)",
            },
            {
                "table": "labs",
                "file": "labs.csv",
                "columns": "(id, person_id, ordering_date_shifted, procedure_id, procedure_name, procedure_code, order_type, order_status, order_proc_deid, description, comp_result_name, ord_value, ord_num_value, reference_low, reference_high, reference_unit, result_flag, lab_status)",
            },
        ]

        for table_config in tables:
            table = table_config["table"]
            print(f"📥 Loading CSV file {table}.csv into Observer database...")
            query = build_load_query(table_config)
            cursor.execute(query)
            conn.commit()

        print("All data loaded successfully!")

    except mysql.connector.Error as err:
        print(f"Error: {err}")
    finally:
        if cursor is not None:
            cursor.close()
        if conn is not None and conn.is_connected():
            conn.close()
            print("Database connection closed.")


if __name__ == "__main__":
    base_path = r"C:\Users\mhill1\Downloads\latest"
    host = "localhost"
    user = "observer"
    password = "observer_password"
    database = "observer_research"

    load_csv_to_mariadb(base_path, host, user, password, database)