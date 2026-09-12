-- Create Salaries Table in PostgreSQL operasyonel_db
DROP TABLE IF EXISTS public.salaries CASCADE;

CREATE TABLE public.salaries (
    emp_id VARCHAR(10) PRIMARY KEY,
    employee_name VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    base_salary NUMERIC(10, 2) NOT NULL
);

-- Seed Initial Salaries Data
INSERT INTO public.salaries (emp_id, employee_name, department, base_salary) VALUES
('EMP001', 'Caner Yilmaz', 'Engineering', 95000.00),
('EMP002', 'Elif Demir', 'Product', 88000.00),
('EMP003', 'Murat Kaya', 'Data Science', 92000.00),
('EMP004', 'Zeynep Celik', 'Security', 90000.00),
('EMP005', 'Ahmet Ozturk', 'Operations', 75000.00);

