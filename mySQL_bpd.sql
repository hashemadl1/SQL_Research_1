USE NBC_PRACTICE;

-- Create the function for calculating Paques
DROP FUNCTION IF EXISTS calculate_paques;

DELIMITER //

CREATE FUNCTION calculate_paques(annee INT)
RETURNS DATE DETERMINISTIC
BEGIN
    DECLARE a INT;
    DECLARE b INT;
    DECLARE c INT;
    DECLARE d INT;
    DECLARE e INT;
    DECLARE de INT;
    DECLARE paques DATE;

    SET a = MOD(annee, 19);
    SET b = MOD(annee, 4);
    SET c = MOD(annee, 7);
    SET d = MOD((19 * a + 24), 30);
    SET e = MOD((2 * b + 4 * c + 6 * d + 5), 7);
    SET de = d + e;

    IF de > 9 THEN
        SET paques = STR_TO_DATE(CONCAT(CAST(de - 9 AS CHAR), '/04/', CAST(annee AS CHAR)), '%d/%m/%Y');
    ELSE
        SET paques = STR_TO_DATE(CONCAT(CAST(22 + de AS CHAR), '/03/', CAST(annee AS CHAR)), '%d/%m/%Y');
    END IF;

    IF paques > STR_TO_DATE(CONCAT('25/04/', CAST(annee AS CHAR)), '%d/%m/%Y') THEN
        SET paques = paques - INTERVAL 7 DAY;
    END IF;

    RETURN paques;
END//

DELIMITER ;

-- Drop table dim_year;
CREATE TABLE IF NOT EXISTS NBC_PRACTICE.dim_year (
    year_key INT NOT NULL AUTO_INCREMENT,   -- Primary key.
    _year INT,     -- Year: 2010
    noel DATE,			-- Date value, in YYYY-MM-DD, 2008-08-18
    newyear DATE,		-- Date value, in YYYY-MM-DD, 2008-08-18
    laborday DATE,		-- Date value, in YYYY-MM-DD, 2008-08-18
    paques DATE, 		-- Date value, in YYYY-MM-DD, 2008-08-18
    created_date TIMESTAMP NOT NULL,  -- Date record was created
    updated_date TIMESTAMP NOT NULL, -- Date record was updated
    PRIMARY KEY (year_key)
);

DROP PROCEDURE IF EXISTS sp_year_dim;
TRUNCATE TABLE dim_year;
DELIMITER //

CREATE PROCEDURE sp_year_dim()
BEGIN
    DECLARE StartYear INT;
    DECLARE EndYear INT;
    DECLARE RunYear INT;

    -- Set date variables
    SET StartYear = 2000; -- Update this value to reflect the earliest date that you will use.
    SET EndYear = 2100; -- Update this value to reflect the latest date that you will use.
    SET RunYear = StartYear;

    -- Loop through each date and insert into DimTime table
    WHILE RunYear <= EndYear DO
        INSERT INTO dim_year (
            _year,
            noel,
            laborday,
            newyear,
            paques,
            created_date,
            updated_date
        )
        SELECT
            RunYear,
            DATE_ADD(DATE_ADD(MAKEDATE(RunYear, 1), INTERVAL 11 MONTH), INTERVAL 24 DAY) AS noel,
            ADDDATE(DATE_ADD(MAKEDATE(RunYear, 1), INTERVAL 8 MONTH), MOD((9 - DAYOFWEEK(DATE_ADD(MAKEDATE(RunYear, 1), INTERVAL 8 MONTH))), 7)) AS laborday,
            MAKEDATE(RunYear, 1) AS newyear,
            calculate_paques(RunYear) AS paques,
            NOW() AS created_date,
            NOW() AS updated_date;

        -- Increase the value of the RunYear variable by 1 day
        SET RunYear = RunYear + 1;
    END WHILE;

    COMMIT;
END//

DELIMITER ;

CALL sp_year_dim();

SELECT * FROM dim_year;
-- Create the function for calculating last working day
DROP FUNCTION IF EXISTS calculate_last_working_day;

DELIMITER //

CREATE FUNCTION calculate_last_working_day(bpd DATE, newyear DATE, noel DATE, paques DATE, laborday DATE)
RETURNS DATE DETERMINISTIC
BEGIN
    DECLARE lwd DATE;
    
    IF bpd = DATE_ADD(laborday, INTERVAL 1 DAY) THEN
        SET lwd = DATE_ADD(bpd, INTERVAL -4 DAY);

    ELSEIF bpd = DATE_ADD(noel, INTERVAL 1 DAY) THEN
        IF DAYOFWEEK(DATE_ADD(bpd, INTERVAL -2 DAY)) = 1 THEN
            SET lwd = DATE_ADD(bpd, INTERVAL -4 DAY);
        ELSEIF DAYOFWEEK(DATE_ADD(bpd, INTERVAL -2 DAY)) = 7 THEN
            SET lwd = DATE_ADD(bpd, INTERVAL -3 DAY);
        ELSE
            SET lwd = DATE_ADD(bpd, INTERVAL -2 DAY);
        END IF;

    ELSEIF bpd = DATE_ADD(newyear, INTERVAL 1 DAY) THEN
        IF DAYOFWEEK(DATE_ADD(bpd, INTERVAL -2 DAY)) = 1 THEN
            SET lwd = DATE_ADD(bpd, INTERVAL -4 DAY);
        ELSEIF DAYOFWEEK(DATE_ADD(bpd, INTERVAL -2 DAY)) = 7 THEN
            SET lwd = DATE_ADD(bpd, INTERVAL -3 DAY);
        ELSE
            SET lwd = DATE_ADD(bpd, INTERVAL -2 DAY);
        END IF;

    ELSEIF bpd = DATE_ADD(paques, INTERVAL 2 DAY) THEN
        IF DAYOFWEEK(DATE_ADD(bpd, INTERVAL -1 DAY)) = 2 THEN
            SET lwd = DATE_ADD(bpd, INTERVAL -4 DAY);
        ELSEIF DAYOFWEEK(DATE_ADD(bpd, INTERVAL -1 DAY)) = 1 THEN
            SET lwd = DATE_ADD(bpd, INTERVAL -3 DAY);
        END IF;

    ELSEIF DAYOFWEEK(bpd) = 2 THEN
        SET lwd = DATE_ADD(bpd, INTERVAL -3 DAY);
    ELSEIF DAYOFWEEK(bpd) = 1 THEN
        SET lwd = DATE_ADD(bpd, INTERVAL -2 DAY);
    ELSEIF DAYOFWEEK(bpd) = 7 THEN
        SET lwd = DATE_ADD(bpd, INTERVAL -1 DAY);
    ELSE
        SET lwd = DATE_ADD(bpd, INTERVAL -1 DAY);
    END IF;

    RETURN lwd;
END //

DELIMITER ;

select bpd as business_process_dt, dayofweek(bpd),
calculate_last_working_day(oss.bpd , d.newyear , d.noel , d.paques , d.laborday ) as pro_dte 
from oss inner join dim_year d 
	ON YEAR(oss.bpd) = d._year
order by 1 desc;
-- select * from dim_year;	


