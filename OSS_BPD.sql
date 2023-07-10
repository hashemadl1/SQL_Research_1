-- Create or replace the database NBC_PRACTICE;
USE DATABASE NBC_PRACTICE;

-- Create the function for calculating Paques
CREATE OR REPLACE FUNCTION calculate_paques(annee INT)
RETURNS DATE
AS
$$
DECLARE
    a INT;
    b INT;
    c INT;
    d INT;
    e INT;
    de INT;
    paques DATE;
BEGIN
    a := MOD(annee, 19);
    b := MOD(annee, 4);
    c := MOD(annee, 7);
    d := MOD((19 * a + 24), 30);
    e := MOD((2 * b + 4 * c + 6 * d + 5), 7);
    de := d + e;

    IF de > 9 THEN
        paques := TO_DATE(TO_CHAR(de - 9) || '/04/' || TO_CHAR(annee), 'DD/MM/YYYY');
    ELSE
        paques := TO_DATE(TO_CHAR(22 + de) || '/03/' || TO_CHAR(annee), 'DD/MM/YYYY');
    END IF;

    IF paques > TO_DATE('25/04/' || TO_CHAR(annee), 'DD/MM/YYYY') THEN
        paques := paques - INTERVAL '7' DAY;
    END IF;

    RETURN paques;
END;
$$
;

-- Drop table dim_year;
CREATE OR REPLACE TABLE NBC_PRACTICE.dim_year (
    year_key INT AUTOINCREMENT PRIMARY KEY,   -- Primary key.
    _year INT,     -- Year: 2010
    noel DATE,     -- Date value, in YYYY-MM-DD, 2008-08-18
    newyear DATE,  -- Date value, in YYYY-MM-DD, 2008-08-18
    laborday DATE, -- Date value, in YYYY-MM-DD, 2008-08-18
    paques DATE,   -- Date value, in YYYY-MM-DD, 2008-08-18
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),  -- Date record was created
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP(), -- Date record was updated
);

-- Drop procedure sp_year_dim;
CREATE OR REPLACE PROCEDURE sp_year_dim()
RETURNS STRING
LANGUAGE JAVASCRIPT
AS
$$
{
    var StartYear = 2000; // Update this value to reflect the earliest date that you will use.
    var EndYear = 2100; // Update this value to reflect the latest date that you will use.
    var RunYear = StartYear;

    while (RunYear <= EndYear) {
        var sqlStatement = `
            INSERT INTO dim_year (_year, noel, laborday, newyear, paques)
            SELECT
                ${RunYear} AS _year,
                DATEADD(DAY, 24, DATEADD(MONTH, 11, MAKEDATE(${RunYear}, 1))) AS noel,
                DATEADD(DAY, MOD((9 - DAYOFWEEK(DATEADD(MONTH, 8, MAKEDATE(${RunYear}, 1)))), 7), DATEADD(MONTH, 8, MAKEDATE(${RunYear}, 1))) AS laborday,
                MAKEDATE(${RunYear}, 1) AS newyear,
                calculate_paques(${RunYear}) AS paques;
        `;
        snowflake.execute({ sqlText: sqlStatement });

        RunYear++;
    }

    return 'Procedure executed successfully.';
}
$$;

CALL sp_year_dim();

SELECT * FROM NBC_PRACTICE.dim_year;


-- Create the function for calculating the last working day
CREATE OR REPLACE FUNCTION calculate_last_working_day(bpd DATE, newyear DATE, noel DATE, paques DATE, laborday DATE)
RETURNS DATE
AS
$$
DECLARE
    lwd DATE;
BEGIN
    IF bpd = DATEADD(DAY, 1, laborday) THEN
        SET lwd = DATEADD(DAY, -4, bpd);
        
    ELSEIF bpd = DATEADD(DAY, 1, noel) THEN
        IF DAYOFWEEK(DATEADD(DAY, -2, bpd)) = 1 THEN
            SET lwd = DATEADD(DAY, -4, bpd);
        ELSEIF DAYOFWEEK(DATEADD(DAY, -2, bpd)) = 7 THEN
            SET lwd = DATEADD(DAY, -3, bpd);
        ELSE
            SET lwd = DATEADD(DAY, -2, bpd);
        END IF;
        
    ELSEIF bpd = DATEADD(DAY, 1, newyear) THEN
        IF DAYOFWEEK(DATEADD(DAY, -2, bpd)) = 1 THEN
            SET lwd = DATEADD(DAY, -4, bpd);
        ELSEIF DAYOFWEEK(DATEADD(DAY, -2, bpd)) = 7 THEN
            SET lwd = DATEADD(DAY, -3, bpd);
        ELSE
            SET lwd = DATEADD(DAY, -2, bpd);
        END IF;
        
    ELSEIF bpd = DATEADD(DAY, 2, paques) THEN
        IF DAYOFWEEK(DATEADD(DAY, -1, bpd)) = 2 THEN
            SET lwd = DATEADD(DAY, -4, bpd);
        ELSEIF DAYOFWEEK(DATEADD(DAY, -1, bpd)) = 1 THEN
            SET lwd = DATEADD(DAY, -3, bpd);
        END IF;
        
    ELSEIF DAYOFWEEK(bpd) = 2 THEN
        SET lwd = DATEADD(DAY, -3, bpd);
    ELSEIF DAYOFWEEK(bpd) = 1 THEN
        SET lwd = DATEADD(DAY, -2, bpd);
    ELSEIF DAYOFWEEK(bpd) = 7 THEN
        SET lwd = DATEADD(DAY, -1, bpd);
    ELSE
        SET lwd = DATEADD(DAY, -1, bpd);
    END IF;
    
    RETURN lwd;
END;
$$;

-- Joining the main table 
select bpd as business_process_dt, dayofweek(bpd),
calculate_last_working_day(oss.bpd , d.newyear , d.noel , d.paques , d.laborday ) as pro_dte 
from oss inner join dim_year d 
	ON YEAR(oss.bpd) = d._year
order by 1 desc;