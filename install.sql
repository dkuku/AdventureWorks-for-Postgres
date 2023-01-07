-- AdventureWorks for Postgres
--  by Lorin Thwaits

-- How to use this script:

-- Download "Adventure Works 2014 OLTP Script" from:
--   https://msftdbprodsamples.codeplex.com/downloads/get/880662

-- Extract the .zip and copy all of the CSV files into the same folder containing
-- this install.sql file and the update_csvs.rb file.

-- Modify the CSVs to work with Postgres by running:
--   ruby update_csvs.rb

-- Create the database and tables, import the data, and set up the views and keys with:
--   psql -c "CREATE DATABASE \"Adventureworks\";"
--   psql -d Adventureworks < install.sql

-- All 68 tables are properly set up.
-- All 20 views are established.
-- 68 additional convenience views are added which:
--   * Provide a shorthand to refer to tables.
--   * Add an "id" column to a primary key or primary-ish key if it makes sense.
--
--   For example, with the convenience views you can simply do:
--       SELECT pe.p.firstname, hr.e.jobtitle
--       FROM pe.p
--         INNER JOIN hr.e ON pe.p.id = hr.e.id;
--   Instead of:
--       SELECT p.firstname, e.jobtitle
--       FROM person.person AS p
--         INNER JOIN humanresources.employee AS e ON p.business_entity_id = e.business_entity_id;
--
-- Schemas for these views:
--   pe = person
--   hr = humanresources
--   pr = production
--   pu = purchasing
--   sa = sales
-- Easily get a list of all of these with:  \dv (pe|hr|pr|pu|sa).*

-- Enjoy!


-- -- Disconnect all other existing connections
-- SELECT pg_terminate_backend(pid)
--   FROM pg_stat_activity
--   WHERE pid <> pg_backend_pid() AND datname='Adventureworks';

\pset tuples_only on

-- Support to auto-generate UUIDs (aka GUIDs)
create extension if not exists "uuid-ossp";

-- Support crosstab function to do PIVOT thing for Sales.vSalesPersonSalesByFiscalYears
create extension tablefunc;

-------------------------------------
-- Custom data types
-------------------------------------

create domain "order_number" varchar(25) null;
create domain "account_number" varchar(15) null;

create domain "flag" boolean not null;
create domain "name_style" boolean not null;
create domain "name" varchar(50) null;
create domain "phone" varchar(25) null;


-------------------------------------
-- Five schemas, with tables and data
-------------------------------------

create schema person
  create table business_entity(
    business_entity_id serial, --  not for replication
    rowguid uuid not null constraint "df_business_entity_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_business_entity_modified_date" default (now())
  )
  create table person(
    business_entity_id int not null,
    person_type char(2) not null,
    name_style "name_style" not null constraint "df_person_name_style" default (false),
    title varchar(8) null,
    first_name "name" not null,
    middle_name "name" null,
    last_name "name" not null,
    suffix varchar(10) null,
    email_promotion int not null constraint "df_person_email_promotion" default (0),
    additional_contact_info xml null, -- xml("additional_contact_info_schema_collection"),
    demographics xml null, -- xml("individual_survey_schema_collection"),
    rowguid uuid not null constraint "df_person_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_person_modified_date" default (now()),
    constraint "ck_person_email_promotion" check (email_promotion between 0 and 2),
    constraint "ck_person_person_type" check (person_type is null or upper(person_type) in ('SC', 'VC', 'IN', 'EM', 'SP', 'GC'))
  )
  create table state_province(
    state_province_id serial,
    state_province_code char(3) not null,
    country_region_code varchar(3) not null,
    is_only_state_province_flag "flag" not null constraint "df_state_province_is_only_state_province_flag" default (true),
    name "name" not null,
    territory_id int not null,
    rowguid uuid not null constraint "df_state_province_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_state_province_modified_date" default (now())
  )
  create table address(
    address_id serial, --  not for replication
    address_line1 varchar(60) not null,
    address_line2 varchar(60) null,
    city varchar(30) not null,
    state_province_id int not null,
    postal_code varchar(15) not null,
    spatial_location varchar(44) null,
    rowguid uuid not null constraint "df_address_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_address_modified_date" default (now())
  )
  create table address_type(
    address_type_id serial,
    name "name" not null,
    rowguid uuid not null constraint "df_address_type_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_address_type_modified_date" default (now())
  )
  create table business_entity_address(
    business_entity_id int not null,
    address_id int not null,
    address_type_id int not null,
    rowguid uuid not null constraint "df_business_entity_address_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_business_entity_address_modified_date" default (now())
  )
  create table contact_type(
    contact_type_id serial,
    name "name" not null,
    modified_date timestamp not null constraint "df_contact_type_modified_date" default (now())
  )
  create table business_entity_contact(
    business_entity_id int not null,
    person_id int not null,
    contact_type_id int not null,
    rowguid uuid not null constraint "df_business_entity_contact_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_business_entity_contact_modified_date" default (now())
  )
  create table email_address(
    business_entity_id int not null,
    email_address_id serial,
    email_address varchar(50) null,
    rowguid uuid not null constraint "df_email_address_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_email_address_modified_date" default (now())
  )
  create table password(
    business_entity_id int not null,
    password_hash varchar(128) not null,
    password_salt varchar(10) not null,
    rowguid uuid not null constraint "df_password_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_password_modified_date" default (now())
  )
  create table phone_number_type(
    phone_number_type_id serial,
    name "name" not null,
    modified_date timestamp not null constraint "df_phone_number_type_modified_date" default (now())
  )
  create table person_phone(
    business_entity_id int not null,
    phone_number "phone" not null,
    phone_number_type_id int not null,
    modified_date timestamp not null constraint "df_person_phone_modified_date" default (now())
  )
  create table country_region(
    country_region_code varchar(3) not null,
    name "name" not null,
    modified_date timestamp not null constraint "df_country_region_modified_date" default (now())
  );

comment on schema person is 'contains objects related to names and addresses of customers, vendors, and employees';

select 'copying data into person.business_entity';
\copy person.business_entity from './BusinessEntity.csv' delimiter e'\t' csv;
select 'copying data into person.person';
\copy person.person from './Person.csv' delimiter e'\t' csv;
select 'copying data into person.state_province';
\copy person.state_province from './StateProvince.csv' delimiter e'\t' csv;
select 'copying data into person.address';
\copy person.address from './Address.csv' delimiter e'\t' csv encoding 'latin1';
select 'copying data into person.address_type';
\copy person.address_type from './AddressType.csv' delimiter e'\t' csv;
select 'copying data into person.business_entity_address';
\copy person.business_entity_address from './BusinessEntityAddress.csv' delimiter e'\t' csv;
select 'copying data into person.contact_type';
\copy person.contact_type from './ContactType.csv' delimiter e'\t' csv;
select 'copying data into person.business_entity_contact';
\copy person.business_entity_contact from './BusinessEntityContact.csv' delimiter e'\t' csv;
select 'copying data into person.email_address';
\copy person.email_address from './EmailAddress.csv' delimiter e'\t' csv;
select 'copying data into person.password';
\copy person.password from './Password.csv' delimiter e'\t' csv;
select 'copying data into person.phone_number_type';
\copy person.phone_number_type from './PhoneNumberType.csv' delimiter e'\t' csv;
select 'copying data into person.person_phone';
\copy person.person_phone from './PersonPhone.csv' delimiter e'\t' csv;
select 'copying data into person.country_region';
\copy person.country_region from './CountryRegion.csv' delimiter e'\t' csv;


create schema human_resources
  create table department(
    department_id serial not null, -- smallint
    name "name" not null,
    group_name "name" not null,
    modified_date timestamp not null constraint "df_department_modified_date" default (now())
  )
  create table employee(
    business_entity_id int not null,
    national_id_number varchar(15) not null,
    login_id varchar(256) not null,    
    org varchar null,-- hierarchyid, will become organization_node
    organization_level int null, -- as organization_node.get_level(),
    job_title varchar(50) not null,
    birth_date date not null,
    marital_status char(1) not null,
    gender char(1) not null,
    hire_date date not null,
    salaried_flag "flag" not null constraint "df_employee_salaried_flag" default (true),
    vacation_hours smallint not null constraint "df_employee_vacation_hours" default (0),
    sick_leave_hours smallint not null constraint "df_employee_sick_leave_hours" default (0),
    current_flag "flag" not null constraint "df_employee_current_flag" default (true),
    rowguid uuid not null constraint "df_employee_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_employee_modified_date" default (now()),
    constraint "ck_employee_birth_date" check (birth_date between '1930-01-01' and now() - interval '18 years'),
    constraint "ck_employee_marital_status" check (upper(marital_status) in ('M', 'S')), -- married or single
    constraint "ck_employee_hire_date" check (hire_date between '1996-07-01' and now() + interval '1 day'),
    constraint "ck_employee_gender" check (upper(gender) in ('M', 'F')), -- male or female
    constraint "ck_employee_vacation_hours" check (vacation_hours between -40 and 240),
    constraint "ck_employee_sick_leave_hours" check (sick_leave_hours between 0 and 120)
  )
  create table employee_department_history(
    business_entity_id int not null,
    department_id smallint not null,
    shift_id smallint not null, -- tinyint
    start_date date not null,
    end_date date null,
    modified_date timestamp not null constraint "df_employee_department_history_modified_date" default (now()),
    constraint "ck_employee_department_history_end_date" check ((end_date >= start_date) or (end_date is null))
  )
  create table employee_pay_history(
    business_entity_id int not null,
    rate_change_date timestamp not null,
    rate numeric not null, -- money
    pay_frequency smallint not null,  -- tinyint
    modified_date timestamp not null constraint "df_employee_pay_history_modified_date" default (now()),
    constraint "ck_employee_pay_history_pay_frequency" check (pay_frequency in (1, 2)), -- 1 = monthly salary, 2 = biweekly salary
    constraint "ck_employee_pay_history_rate" check (rate between 6.50 and 200.00)
  )
  create table job_candidate(
    job_candidate_id serial not null, -- int
    business_entity_id int null,
    resume xml null, -- xml(hr_resume_schema_collection)
    modified_date timestamp not null constraint "df_job_candidate_modified_date" default (now())
  )
  create table shift(
    shift_id serial not null, -- tinyint
    name "name" not null,
    start_time time not null,
    end_time time not null,
    modified_date timestamp not null constraint "df_shift_modified_date" default (now())
  );

comment on schema human_resources is 'contains objects related to employees and departments.';

select 'copying data into human_resources.department';
\copy human_resources.department from './Department.csv' delimiter e'\t' csv;
select 'copying data into human_resources.employee';
\copy human_resources.employee from './Employee.csv' delimiter e'\t' csv;
select 'copying data into human_resources.employee_department_history';
\copy human_resources.employee_department_history from './EmployeeDepartmentHistory.csv' delimiter e'\t' csv;
select 'copying data into human_resources.employee_pay_history';
\copy human_resources.employee_pay_history from './EmployeePayHistory.csv' delimiter e'\t' csv;
select 'copying data into human_resources.job_candidate';
\copy human_resources.job_candidate from './JobCandidate.csv' delimiter e'\t' csv encoding 'latin1';
select 'copying data into human_resources.shift';
\copy human_resources.shift from './Shift.csv' delimiter e'\t' csv;

-- Calculated column that needed to be there just for the CSV import
alter table human_resources.employee drop column organization_level;

-- Employee HierarchyID column
alter table human_resources.employee add organization_node varchar default '/';
-- Convert from all the hex to a stream of hierarchyid bits
with recursive hier as (
  select business_entity_id, org, get_byte(decode(substring(org, 1, 2), 'hex'), 0)::bit(8)::varchar as bits, 2 as i
    from human_resources.employee
  union all
  select e.business_entity_id, e.org, hier.bits || get_byte(decode(substring(e.org, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 as i
    from human_resources.employee as e inner join
      hier on e.business_entity_id = hier.business_entity_id and i < length(e.org)
)
update human_resources.employee as emp
  set org = coalesce(trim(trailing '0' from hier.bits::text), '')
  from hier
  where emp.business_entity_id = hier.business_entity_id
    and (hier.org is null or i = length(hier.org));

-- Convert bits to the real hieararchy paths
create or replace function f_convert_org_nodes()
  returns void as
$func$
declare
  got_none boolean;
begin
  loop
  got_none := true;
  -- 01 = 0-3
  update human_resources.employee
   set organization_node = organization_node || substring(org, 3,2)::bit(2)::integer::varchar || case substring(org, 5, 1) when '0' then '.' else '/' end,
     org = substring(org, 6, 9999)
    where org like '01%';
  if found then
    got_none := false;
  end if;

  -- 100 = 4-7
  update human_resources.employee
   set organization_node = organization_node || (substring(org, 4,2)::bit(2)::integer + 4)::varchar || case substring(org, 6, 1) when '0' then '.' else '/' end,
     org = substring(org, 7, 9999)
    where org like '100%';
  if found then
    got_none := false;
  end if;
  
  -- 101 = 8-15
  update human_resources.employee
   set organization_node = organization_node || (substring(org, 4,3)::bit(3)::integer + 8)::varchar || case substring(org, 7, 1) when '0' then '.' else '/' end,
     org = substring(org, 8, 9999)
    where org like '101%';
  if found then
    got_none := false;
  end if;

  -- 110 = 16-79
  update human_resources.employee
   set organization_node = organization_node || ((substring(org, 4,2)||substring(org, 7,1)||substring(org, 9,3))::bit(6)::integer + 16)::varchar || case substring(org, 12, 1) when '0' then '.' else '/' end,
     org = substring(org, 13, 9999)
    where org like '110%';
  if found then
    got_none := false;
  end if;

  -- 1110 = 80-1103
  update human_resources.employee
   set organization_node = organization_node || ((substring(org, 5,3)||substring(org, 9,3)||substring(org, 13,1)||substring(org, 15,3))::bit(10)::integer + 80)::varchar || case substring(org, 18, 1) when '0' then '.' else '/' end,
     org = substring(org, 19, 9999)
    where org like '1110%';
  if found then
    got_none := false;
  end if;
  exit when got_none;
  end loop;
end
$func$ language plpgsql;

select f_convert_org_nodes();
-- Drop the original binary hierarchyid column
alter table human_resources.employee drop column org;
drop function f_convert_org_nodes();




create schema production
  create table bill_of_materials(
    bill_of_materials_id serial not null, -- int
    product_assembly_id int null,
    component_id int not null,
    start_date timestamp not null constraint "df_bill_of_materials_start_date" default (now()),
    end_date timestamp null,
    unit_measure_code char(3) not null,
    bom_level smallint not null,
    per_assembly_qty decimal(8, 2) not null constraint "df_bill_of_materials_per_assembly_qty" default (1.00),
    modified_date timestamp not null constraint "df_bill_of_materials_modified_date" default (now()),
    constraint "ck_bill_of_materials_end_date" check ((end_date > start_date) or (end_date is null)),
    constraint "ck_bill_of_materials_product_assembly_id" check (product_assembly_id <> component_id),
    constraint "ck_bill_of_materials_bom_level" check (((product_assembly_id is null)
        and (bom_level = 0) and (per_assembly_qty = 1.00))
        or ((product_assembly_id is not null) and (bom_level >= 1))),
    constraint "ck_bill_of_materials_per_assembly_qty" check (per_assembly_qty >= 1.00)
  )
  create table culture(
    culture_id char(6) not null,
    name "name" not null,
    modified_date timestamp not null constraint "df_culture_modified_date" default (now())
  )
  create table document(
    doc varchar null,-- hierarchyid, will become document_node
    document_level integer, -- as document_node.get_level(),
    title varchar(50) not null,
    owner int not null,
    folder_flag "flag" not null constraint "df_document_folder_flag" default (false),
    file_name varchar(400) not null,
    file_extension varchar(8) null,
    revision char(5) not null,
    change_number int not null constraint "df_document_change_number" default (0),
    status smallint not null, -- tinyint
    document_summary text null,
    document bytea  null, -- varbinary
    rowguid uuid not null unique constraint "df_document_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_document_modified_date" default (now()),
    constraint "ck_document_status" check (status between 1 and 3)
  )
  create table product_category(
    product_category_id serial not null, -- int
    name "name" not null,
    rowguid uuid not null constraint "df_product_category_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_product_category_modified_date" default (now())
  )
  create table product_subcategory(
    product_subcategory_id serial not null, -- int
    product_category_id int not null,
    name "name" not null,
    rowguid uuid not null constraint "df_product_subcategory_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_product_subcategory_modified_date" default (now())
  )
  create table product_model(
    product_model_id serial not null, -- int
    name "name" not null,
    catalog_description xml null, -- xml(production.product_description_schema_collection)
    instructions xml null, -- xml(production.manu_instructions_schema_collection)
    rowguid uuid not null constraint "df_product_model_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_product_model_modified_date" default (now())
  )
  create table product(
    product_id serial not null, -- int
    name "name" not null,
    product_number varchar(25) not null,
    make_flag "flag" not null constraint "df_product_make_flag" default (true),
    finished_goods_flag "flag" not null constraint "df_product_finished_goods_flag" default (true),
    color varchar(15) null,
    safety_stock_level smallint not null,
    reorder_point smallint not null,
    standard_cost numeric not null, -- money
    list_price numeric not null, -- money
    size varchar(5) null,
    size_unit_measure_code char(3) null,
    weight_unit_measure_code char(3) null,
    weight decimal(8, 2) null,
    days_to_manufacture int not null,
    product_line char(2) null,
    class char(2) null,
    style char(2) null,
    product_subcategory_id int null,
    product_model_id int null,
    sell_start_date timestamp not null,
    sell_end_date timestamp null,
    discontinued_date timestamp null,
    rowguid uuid not null constraint "df_product_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_product_modified_date" default (now()),
    constraint "ck_product_safety_stock_level" check (safety_stock_level > 0),
    constraint "ck_product_reorder_point" check (reorder_point > 0),
    constraint "ck_product_standard_cost" check (standard_cost >= 0.00),
    constraint "ck_product_list_price" check (list_price >= 0.00),
    constraint "ck_product_weight" check (weight > 0.00),
    constraint "ck_product_days_to_manufacture" check (days_to_manufacture >= 0),
    constraint "ck_product_product_line" check (upper(product_line) in ('S', 'T', 'M', 'R') or product_line is null),
    constraint "ck_product_class" check (upper(class) in ('L', 'M', 'H') or class is null),
    constraint "ck_product_style" check (upper(style) in ('W', 'M', 'U') or style is null),
    constraint "ck_product_sell_end_date" check ((sell_end_date >= sell_start_date) or (sell_end_date is null))
  )
  create table product_cost_history(
    product_id int not null,
    start_date timestamp not null,
    end_date timestamp null,
    standard_cost numeric not null,  -- money
    modified_date timestamp not null constraint "df_product_cost_history_modified_date" default (now()),
    constraint "ck_product_cost_history_end_date" check ((end_date >= start_date) or (end_date is null)),
    constraint "ck_product_cost_history_standard_cost" check (standard_cost >= 0.00)
  )
  create table product_description(
    product_description_id serial not null, -- int
    description varchar(400) not null,
    rowguid uuid not null constraint "df_product_description_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_product_description_modified_date" default (now())
  )
  create table product_document(
    product_id int not null,
    doc varchar not null, -- hierarchyid, will become document_node
    modified_date timestamp not null constraint "df_product_document_modified_date" default (now())
  )
  create table location(
    location_id serial not null, -- smallint
    name "name" not null,
    cost_rate numeric not null constraint "df_location_cost_rate" default (0.00), -- smallmoney -- money
    availability decimal(8, 2) not null constraint "df_location_availability" default (0.00),
    modified_date timestamp not null constraint "df_location_modified_date" default (now()),
    constraint "ck_location_cost_rate" check (cost_rate >= 0.00),
    constraint "ck_location_availability" check (availability >= 0.00)
  )
  create table product_inventory(
    product_id int not null,
    location_id smallint not null,
    shelf varchar(10) not null,
    bin smallint not null, -- tinyint
    quantity smallint not null constraint "df_product_inventory_quantity" default (0),
    rowguid uuid not null constraint "df_product_inventory_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_product_inventory_modified_date" default (now()),
--    CONSTRAINT "CK_ProductInventory_Shelf" CHECK ((Shelf LIKE 'AZa-z]') OR (Shelf = 'N/A')),
    constraint "ck_product_inventory_bin" check (bin between 0 and 100)
  )
  create table product_list_price_history(
    product_id int not null,
    start_date timestamp not null,
    end_date timestamp null,
    list_price numeric not null,  -- money
    modified_date timestamp not null constraint "df_product_list_price_history_modified_date" default (now()),
    constraint "ck_product_list_price_history_end_date" check ((end_date >= start_date) or (end_date is null)),
    constraint "ck_product_list_price_history_list_price" check (list_price > 0.00)
  )
  create table illustration(
    illustration_id serial not null, -- int
    diagram xml null,
    modified_date timestamp not null constraint "df_illustration_modified_date" default (now())
  )
  create table product_model_illustration(
    product_model_id int not null,
    illustration_id int not null,
    modified_date timestamp not null constraint "df_product_model_illustration_modified_date" default (now())
  )
  create table product_model_product_description_culture(
    product_model_id int not null,
    product_description_id int not null,
    culture_id char(6) not null,
    modified_date timestamp not null constraint "df_product_model_product_description_culture_modified_date" default (now())
  )
  create table product_photo(
    product_photo_id serial not null, -- int
    thumb_nail_photo bytea null,-- varbinary
    thumbnail_photo_file_name varchar(50) null,
    large_photo bytea null,-- varbinary
    large_photo_file_name varchar(50) null,
    modified_date timestamp not null constraint "df_product_photo_modified_date" default (now())
  )
  create table product_product_photo(
    product_id int not null,
    product_photo_id int not null,
    "primary" "flag" not null constraint "df_product_product_photo_primary" default (false),
    modified_date timestamp not null constraint "df_product_product_photo_modified_date" default (now())
  )
  create table product_review(
    product_review_id serial not null, -- int
    product_id int not null,
    reviewer_name "name" not null,
    review_date timestamp not null constraint "df_product_review_review_date" default (now()),
    email_address varchar(50) not null,
    rating int not null,
    comments varchar(3850),
    modified_date timestamp not null constraint "df_product_review_modified_date" default (now()),
    constraint "ck_product_review_rating" check (rating between 1 and 5)
  )
  create table scrap_reason(
    scrap_reason_id serial not null, -- smallint
    name "name" not null,
    modified_date timestamp not null constraint "df_scrap_reason_modified_date" default (now())
  )
  create table transaction_history(
    transaction_id serial not null, -- int identity (100000, 1)
    product_id int not null,
    reference_order_id int not null,
    reference_order_line_id int not null constraint "df_transaction_history_reference_order_line_id" default (0),
    transaction_date timestamp not null constraint "df_transaction_history_transaction_date" default (now()),
    transaction_type char(1) not null,
    quantity int not null,
    actual_cost numeric not null,  -- money
    modified_date timestamp not null constraint "df_transaction_history_modified_date" default (now()),
    constraint "ck_transaction_history_transaction_type" check (upper(transaction_type) in ('W', 'S', 'P'))
  )
  create table transaction_history_archive(
    transaction_id int not null,
    product_id int not null,
    reference_order_id int not null,
    reference_order_line_id int not null constraint "df_transaction_history_archive_reference_order_line_id" default (0),
    transaction_date timestamp not null constraint "df_transaction_history_archive_transaction_date" default (now()),
    transaction_type char(1) not null,
    quantity int not null,
    actual_cost numeric not null,  -- money
    modified_date timestamp not null constraint "df_transaction_history_archive_modified_date" default (now()),
    constraint "ck_transaction_history_archive_transaction_type" check (upper(transaction_type) in ('W', 'S', 'P'))
  )
  create table unit_measure(
    unit_measure_code char(3) not null,
    name "name" not null,
    modified_date timestamp not null constraint "df_unit_measure_modified_date" default (now())
  )
  create table work_order(
    work_order_id serial not null, -- int
    product_id int not null,
    order_qty int not null,
    stocked_qty int, -- as isnull(order_qty - scrapped_qty, 0),
    scrapped_qty smallint not null,
    start_date timestamp not null,
    end_date timestamp null,
    due_date timestamp not null,
    scrap_reason_id smallint null,
    modified_date timestamp not null constraint "df_work_order_modified_date" default (now()),
    constraint "ck_work_order_order_qty" check (order_qty > 0),
    constraint "ck_work_order_scrapped_qty" check (scrapped_qty >= 0),
    constraint "ck_work_order_end_date" check ((end_date >= start_date) or (end_date is null))
  )
  create table work_order_routing(
    work_order_id int not null,
    product_id int not null,
    operation_sequence smallint not null,
    location_id smallint not null,
    scheduled_start_date timestamp not null,
    scheduled_end_date timestamp not null,
    actual_start_date timestamp null,
    actual_end_date timestamp null,
    actual_resource_hrs decimal(9, 4) null,
    planned_cost numeric not null, -- money
    actual_cost numeric null,  -- money
    modified_date timestamp not null constraint "df_work_order_routing_modified_date" default (now()),
    constraint "ck_work_order_routing_scheduled_end_date" check (scheduled_end_date >= scheduled_start_date),
    constraint "ck_work_order_routing_actual_end_date" check ((actual_end_date >= actual_start_date)
        or (actual_end_date is null) or (actual_start_date is null)),
    constraint "ck_work_order_routing_actual_resource_hrs" check (actual_resource_hrs >= 0.0000),
    constraint "ck_work_order_routing_planned_cost" check (planned_cost > 0.00),
    constraint "ck_work_order_routing_actual_cost" check (actual_cost > 0.00)
  );

comment on schema production is 'contains objects related to products, inventory, and manufacturing.';

select 'copying data into production.bill_of_materials';
\copy production.bill_of_materials from 'BillOfMaterials.csv' delimiter e'\t' csv;
select 'copying data into production.culture';
\copy production.culture from 'Culture.csv' delimiter e'\t' csv;
select 'copying data into production.document';
\copy production.document from 'Document.csv' delimiter e'\t' csv;
select 'copying data into production.product_category';
\copy production.product_category from 'ProductCategory.csv' delimiter e'\t' csv;
select 'copying data into production.product_subcategory';
\copy production.product_subcategory from 'ProductSubcategory.csv' delimiter e'\t' csv;
select 'copying data into production.product_model';
\copy production.product_model from 'ProductModel.csv' delimiter e'\t' csv;
select 'copying data into production.product';
\copy production.product from 'Product.csv' delimiter e'\t' csv;
select 'copying data into production.product_cost_history';
\copy production.product_cost_history from 'ProductCostHistory.csv' delimiter e'\t' csv;
select 'copying data into production.product_description';
\copy production.product_description from 'ProductDescription.csv' delimiter e'\t' csv;
select 'copying data into production.product_document';
\copy production.product_document from 'ProductDocument.csv' delimiter e'\t' csv;
select 'copying data into production.location';
\copy production.location from 'Location.csv' delimiter e'\t' csv;
select 'copying data into production.product_inventory';
\copy production.product_inventory from 'ProductInventory.csv' delimiter e'\t' csv;
select 'copying data into production.product_list_price_history';
\copy production.product_list_price_history from 'ProductListPriceHistory.csv' delimiter e'\t' csv;
select 'copying data into production.illustration';
\copy production.illustration from 'Illustration.csv' delimiter e'\t' csv;
select 'copying data into production.product_model_illustration';
\copy production.product_model_illustration from 'ProductModelIllustration.csv' delimiter e'\t' csv;
select 'copying data into production.product_model_product_description_culture';
\copy production.product_model_product_description_culture from 'ProductModelProductDescriptionCulture.csv' delimiter e'\t' csv;
select 'copying data into production.product_photo';
\copy production.product_photo from 'ProductPhoto.csv' delimiter e'\t' csv;
select 'copying data into production.product_product_photo';
\copy production.product_product_photo from 'ProductProductPhoto.csv' delimiter e'\t' csv;

-- This doesn't work:
-- SELECT 'Copying data into Production.ProductReview';
-- \copy Production.ProductReview FROM 'ProductReview.csv' DELIMITER '  ' CSV;

-- so instead ...
INSERT INTO production.product_review (product_review_id, product_id, reviewer_name, review_date, email_address, rating, comments, modified_date) VALUES
 (1, 709, 'John Smith', '2013-09-18 00:00:00', 'john@fourthcoffee.com', 5, 'I can''t believe I''m singing the praises of a pair of socks, but I just came back from a grueling
3-day ride and these socks really helped make the trip a blast. They''re lightweight yet really cushioned my feet all day. 
The reinforced toe is nearly bullet-proof and I didn''t experience any problems with rubbing or blisters like I have with
other brands. I know it sounds silly, but it''s always the little stuff (like comfortable feet) that makes or breaks a long trip.
I won''t go on another trip without them!', '2013-09-18 00:00:00'),

 (2, 937, 'David', '2013-11-13 00:00:00', 'david@graphicdesigninstitute.com', 4, 'A little on the heavy side, but overall the entry/exit is easy in all conditions. I''ve used these pedals for 
more than 3 years and I''ve never had a problem. Cleanup is easy. Mud and sand don''t get trapped. I would like 
them even better if there was a weight reduction. Maybe in the next design. Still, I would recommend them to a friend.', '2013-11-13 00:00:00'),

 (3, 937, 'Jill', '2013-11-15 00:00:00', 'jill@margiestravel.com', 2, 'Maybe it''s just because I''m new to mountain biking, but I had a terrible time getting use
to these pedals. In my first outing, I wiped out trying to release my foot. Any suggestions on
ways I can adjust the pedals, or is it just a learning curve thing?', '2013-11-15 00:00:00'),

 (4, 798, 'Laura Norman', '2013-11-15 00:00:00', 'laura@treyresearch.net', 5, 'The Road-550-W from Adventure Works Cycles is everything it''s advertised to be. Finally, a quality bike that
is actually built for a woman and provides control and comfort in one neat package. The top tube is shorter, the suspension is weight-tuned and there''s a much shorter reach to the brake
levers. All this adds up to a great mountain bike that is sure to accommodate any woman''s anatomy. In addition to getting the size right, the saddle is incredibly comfortable. 
Attention to detail is apparent in every aspect from the frame finish to the careful design of each component. Each component is a solid performer without any fluff. 
The designers clearly did their homework and thought about size, weight, and funtionality throughout. And at less than 19 pounds, the bike is manageable for even the most petite cyclist.

We had 5 riders take the bike out for a spin and really put it to the test. The results were consistent and very positive. Our testers loved the manuverability 
and control they had with the redesigned frame on the 550-W. A definite improvement over the 2012 design. Four out of five testers listed quick handling
and responsivness were the key elements they noticed. Technical climbing and on the flats, the bike just cruises through the rough. Tight corners and obstacles were handled effortlessly. The fifth tester was more impressed with the smooth ride. The heavy-duty shocks absorbed even the worst bumps and provided a soft ride on all but the 
nastiest trails and biggest drops. The shifting was rated superb and typical of what we''ve come to expect from Adventure Works Cycles. On descents, the bike handled flawlessly and tracked very well. The bike is well balanced front-to-rear and frame flex was minimal. In particular, the testers
noted that the brake system had a unique combination of power and modulation.  While some brake setups can be overly touchy, these brakes had a good
amount of power, but also a good feel that allows you to apply as little or as much braking power as is needed. Second is their short break-in period. We found that they tend to break-in well before
the end of the first ride; while others take two to three rides (or more) to come to full power. 

On the negative side, the pedals were not quite up to our tester''s standards. 
Just for fun, we experimented with routine maintenance tasks. Overall we found most operations to be straight forward and easy to complete. The only exception was replacing the front wheel. The maintenance manual that comes
with the bike say to install the front wheel with the axle quick release or bolt, then compress the fork a few times before fastening and tightening the two quick-release mechanisms on the bottom of the dropouts. This is to seat the axle in the dropouts, and if you do not
do this, the axle will become seated after you tightened the two bottom quick releases, which will then become loose. It''s better to test the tightness carefully or you may notice that the two bottom quick releases have come loose enough to fall completely open. And that''s something you don''t want to experience
while out on the road! 

The Road-550-W frame is available in a variety of sizes and colors and has the same durable, high-quality aluminum that AWC is known for. At a MSRP of just under $1125.00, it''s comparable in price to its closest competitors and
we think that after a test drive you''l find the quality and performance above and beyond . You''ll have a grin on your face and be itching to get out on the road for more. While designed for serious road racing, the Road-550-W would be an excellent choice for just about any terrain and 
any level of experience. It''s a huge step in the right direction for female cyclists and well worth your consideration and hard-earned money.', '2013-11-15 00:00:00');

select 'copying data into production.scrap_reason';
\copy production.scrap_reason from 'ScrapReason.csv' delimiter e'\t' csv;
select 'copying data into production.transaction_history';
\copy production.transaction_history from 'TransactionHistory.csv' delimiter e'\t' csv;
select 'copying data into production.transaction_history_archive';
\copy production.transaction_history_archive from 'TransactionHistoryArchive.csv' delimiter e'\t' csv;
select 'copying data into production.unit_measure';
\copy production.unit_measure from 'UnitMeasure.csv' delimiter e'\t' csv;
select 'copying data into production.work_order';
\copy production.work_order from 'WorkOrder.csv' delimiter e'\t' csv;
select 'copying data into production.work_order_routing';
\copy production.work_order_routing from 'WorkOrderRouting.csv' delimiter e'\t' csv;

-- Calculated columns that needed to be there just for the CSV import
alter table production.work_order drop column stocked_qty;
alter table production.document drop column document_level;

-- Document HierarchyID column
alter table production.document add document_node varchar default '/';
-- Convert from all the hex to a stream of hierarchyid bits
with recursive hier as (
  select rowguid, doc, get_byte(decode(substring(doc, 1, 2), 'hex'), 0)::bit(8)::varchar as bits, 2 as i
    from production.document
  union all
  select e.rowguid, e.doc, hier.bits || get_byte(decode(substring(e.doc, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 as i
    from production.document as e inner join
      hier on e.rowguid = hier.rowguid and i < length(e.doc)
)
update production.document as emp
  set doc = coalesce(trim(trailing '0' from hier.bits::text), '')
  from hier
  where emp.rowguid = hier.rowguid
    and (hier.doc is null or i = length(hier.doc));

-- Convert bits to the real hieararchy paths
create or replace function f_convert_doc_nodes()
  returns void as
$func$
declare
  got_none boolean;
begin
  loop
  got_none := true;
  -- 01 = 0-3
  update production.document
   set document_node = document_node || substring(doc, 3,2)::bit(2)::integer::varchar || case substring(doc, 5, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 6, 9999)
    where doc like '01%';
  if found then
    got_none := false;
  end if;

  -- 100 = 4-7
  update production.document
   set document_node = document_node || (substring(doc, 4,2)::bit(2)::integer + 4)::varchar || case substring(doc, 6, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 7, 9999)
    where doc like '100%';
  if found then
    got_none := false;
  end if;
  
  -- 101 = 8-15
  update production.document
   set document_node = document_node || (substring(doc, 4,3)::bit(3)::integer + 8)::varchar || case substring(doc, 7, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 8, 9999)
    where doc like '101%';
  if found then
    got_none := false;
  end if;

  -- 110 = 16-79
  update production.document
   set document_node = document_node || ((substring(doc, 4,2)||substring(doc, 7,1)||substring(doc, 9,3))::bit(6)::integer + 16)::varchar || case substring(doc, 12, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 13, 9999)
    where doc like '110%';
  if found then
    got_none := false;
  end if;

  -- 1110 = 80-1103
  update production.document
   set document_node = document_node || ((substring(doc, 5,3)||substring(doc, 9,3)||substring(doc, 13,1)||substring(doc, 15,3))::bit(10)::integer + 80)::varchar || case substring(doc, 18, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 19, 9999)
    where doc like '1110%';
  if found then
    got_none := false;
  end if;
  exit when got_none;
  end loop;
end
$func$ language plpgsql;

select f_convert_doc_nodes();
-- Drop the original binary hierarchyid column
alter table production.document drop column doc;
drop function f_convert_doc_nodes();

-- ProductDocument HierarchyID column
  alter table production.product_document add document_node varchar default '/';
alter table production.product_document add rowguid uuid not null constraint "df_product_document_rowguid" default (uuid_generate_v1());
-- Convert from all the hex to a stream of hierarchyid bits
with recursive hier as (
  select rowguid, doc, get_byte(decode(substring(doc, 1, 2), 'hex'), 0)::bit(8)::varchar as bits, 2 as i
    from production.product_document
  union all
  select e.rowguid, e.doc, hier.bits || get_byte(decode(substring(e.doc, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 as i
    from production.product_document as e inner join
      hier on e.rowguid = hier.rowguid and i < length(e.doc)
)
update production.product_document as emp
  set doc = coalesce(trim(trailing '0' from hier.bits::text), '')
  from hier
  where emp.rowguid = hier.rowguid
    and (hier.doc is null or i = length(hier.doc));

-- Convert bits to the real hieararchy paths
create or replace function f_convert_doc_nodes()
  returns void as
$func$
declare
  got_none boolean;
begin
  loop
  got_none := true;
  -- 01 = 0-3
  update production.product_document
   set document_node = document_node || substring(doc, 3,2)::bit(2)::integer::varchar || case substring(doc, 5, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 6, 9999)
    where doc like '01%';
  if found then
    got_none := false;
  end if;

  -- 100 = 4-7
  update production.product_document
   set document_node = document_node || (substring(doc, 4,2)::bit(2)::integer + 4)::varchar || case substring(doc, 6, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 7, 9999)
    where doc like '100%';
  if found then
    got_none := false;
  end if;
  
  -- 101 = 8-15
  update production.product_document
   set document_node = document_node || (substring(doc, 4,3)::bit(3)::integer + 8)::varchar || case substring(doc, 7, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 8, 9999)
    where doc like '101%';
  if found then
    got_none := false;
  end if;

  -- 110 = 16-79
  update production.product_document
   set document_node = document_node || ((substring(doc, 4,2)||substring(doc, 7,1)||substring(doc, 9,3))::bit(6)::integer + 16)::varchar || case substring(doc, 12, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 13, 9999)
    where doc like '110%';
  if found then
    got_none := false;
  end if;

  -- 1110 = 80-1103
  update production.product_document
   set document_node = document_node || ((substring(doc, 5,3)||substring(doc, 9,3)||substring(doc, 13,1)||substring(doc, 15,3))::bit(10)::integer + 80)::varchar || case substring(doc, 18, 1) when '0' then '.' else '/' end,
     doc = substring(doc, 19, 9999)
    where doc like '1110%';
  if found then
    got_none := false;
  end if;
  exit when got_none;
  end loop;
end
$func$ language plpgsql;

select f_convert_doc_nodes();
-- Drop the original binary hierarchyid column
alter table production.product_document drop column doc;
drop function f_convert_doc_nodes();
alter table production.product_document drop column rowguid;





create schema purchasing
  create table product_vendor(
    product_id int not null,
    business_entity_id int not null,
    average_lead_time int not null,
    standard_price numeric not null, -- money
    last_receipt_cost numeric null, -- money
    last_receipt_date timestamp null,
    min_order_qty int not null,
    max_order_qty int not null,
    on_order_qty int null,
    unit_measure_code char(3) not null,
    modified_date timestamp not null constraint "df_product_vendor_modified_date" default (now()),
    constraint "ck_product_vendor_average_lead_time" check (average_lead_time >= 1),
    constraint "ck_product_vendor_standard_price" check (standard_price > 0.00),
    constraint "ck_product_vendor_last_receipt_cost" check (last_receipt_cost > 0.00),
    constraint "ck_product_vendor_min_order_qty" check (min_order_qty >= 1),
    constraint "ck_product_vendor_max_order_qty" check (max_order_qty >= 1),
    constraint "ck_product_vendor_on_order_qty" check (on_order_qty >= 0)
  )
  create table purchase_order_detail(
    purchase_order_id int not null,
    purchase_order_detail_id serial not null, -- int
    due_date timestamp not null,
    order_qty smallint not null,
    product_id int not null,
    unit_price numeric not null, -- money
    line_total numeric, -- as isnull(order_qty * unit_price, 0.00),
    received_qty decimal(8, 2) not null,
    rejected_qty decimal(8, 2) not null,
    stocked_qty numeric, -- as isnull(received_qty - rejected_qty, 0.00),
    modified_date timestamp not null constraint "df_purchase_order_detail_modified_date" default (now()),
    constraint "ck_purchase_order_detail_order_qty" check (order_qty > 0),
    constraint "ck_purchase_order_detail_unit_price" check (unit_price >= 0.00),
    constraint "ck_purchase_order_detail_received_qty" check (received_qty >= 0.00),
    constraint "ck_purchase_order_detail_rejected_qty" check (rejected_qty >= 0.00)
  )
  create table purchase_order_header(
    purchase_order_id serial not null,  -- int
    revision_number smallint not null constraint "df_purchase_order_header_revision_number" default (0),  -- tinyint
    status smallint not null constraint "df_purchase_order_header_status" default (1),  -- tinyint
    employee_id int not null,
    vendor_id int not null,
    ship_method_id int not null,
    order_date timestamp not null constraint "df_purchase_order_header_order_date" default (now()),
    ship_date timestamp null,
    sub_total numeric not null constraint "df_purchase_order_header_sub_total" default (0.00),  -- money
    tax_amt numeric not null constraint "df_purchase_order_header_tax_amt" default (0.00),  -- money
    freight numeric not null constraint "df_purchase_order_header_freight" default (0.00),  -- money
    total_due numeric, -- as isnull(sub_total + tax_amt + freight, 0) persisted not null,
    modified_date timestamp not null constraint "df_purchase_order_header_modified_date" default (now()),
    constraint "ck_purchase_order_header_status" check (status between 1 and 4), -- 1 = pending; 2 = approved; 3 = rejected; 4 = complete
    constraint "ck_purchase_order_header_ship_date" check ((ship_date >= order_date) or (ship_date is null)),
    constraint "ck_purchase_order_header_sub_total" check (sub_total >= 0.00),
    constraint "ck_purchase_order_header_tax_amt" check (tax_amt >= 0.00),
    constraint "ck_purchase_order_header_freight" check (freight >= 0.00)
  )
  create table ship_method(
    ship_method_id serial not null, -- int
    name "name" not null,
    ship_base numeric not null constraint "df_ship_method_ship_base" default (0.00), -- money
    ship_rate numeric not null constraint "df_ship_method_ship_rate" default (0.00), -- money
    rowguid uuid not null constraint "df_ship_method_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_ship_method_modified_date" default (now()),
    constraint "ck_ship_method_ship_base" check (ship_base > 0.00),
    constraint "ck_ship_method_ship_rate" check (ship_rate > 0.00)
  )
  create table vendor(
    business_entity_id int not null,
    account_number "account_number" not null,
    name "name" not null,
    credit_rating smallint not null, -- tinyint
    preferred_vendor_status "flag" not null constraint "df_vendor_preferred_vendor_status" default (true),
    active_flag "flag" not null constraint "df_vendor_active_flag" default (true),
    purchasing_web_service_url varchar(1024) null,
    modified_date timestamp not null constraint "df_vendor_modified_date" default (now()),
    constraint "ck_vendor_credit_rating" check (credit_rating between 1 and 5)
  );

comment on schema purchasing is 'contains objects related to vendors and purchase orders.';

select 'copying data into purchasing.product_vendor';
\copy purchasing.product_vendor from 'ProductVendor.csv' delimiter e'\t' csv;
select 'copying data into purchasing.purchase_order_detail';
\copy purchasing.purchase_order_detail from 'PurchaseOrderDetail.csv' delimiter e'\t' csv;
select 'copying data into purchasing.purchase_order_header';
\copy purchasing.purchase_order_header from 'PurchaseOrderHeader.csv' delimiter e'\t' csv;
select 'copying data into purchasing.ship_method';
\copy purchasing.ship_method from 'ShipMethod.csv' delimiter e'\t' csv;
select 'copying data into purchasing.vendor';
\copy purchasing.vendor from 'Vendor.csv' delimiter e'\t' csv;

-- Calculated columns that needed to be there just for the CSV import
alter table purchasing.purchase_order_detail drop column line_total;
alter table purchasing.purchase_order_detail drop column stocked_qty;
alter table purchasing.purchase_order_header drop column total_due;



create schema sales
  create table country_region_currency(
    country_region_code varchar(3) not null,
    currency_code char(3) not null,
    modified_date timestamp not null constraint "df_country_region_currency_modified_date" default (now())
  )
  create table credit_card(
    credit_card_id serial not null, -- int
    card_type varchar(50) not null,
    card_number varchar(25) not null,
    exp_month smallint not null, -- tinyint
    exp_year smallint not null,
    modified_date timestamp not null constraint "df_credit_card_modified_date" default (now())
  )
  create table currency(
    currency_code char(3) not null,
    name "name" not null,
    modified_date timestamp not null constraint "df_currency_modified_date" default (now())
  )
  create table currency_rate(
    currency_rate_id serial not null, -- int
    currency_rate_date timestamp not null,   
    from_currency_code char(3) not null,
    to_currency_code char(3) not null,
    average_rate numeric not null, -- money
    end_of_day_rate numeric not null,  -- money
    modified_date timestamp not null constraint "df_currency_rate_modified_date" default (now())
  )
  create table customer(
    customer_id serial not null, --  not for replication -- int
    -- a customer may either be a person, a store, or a person who works for a store
    person_id int null, -- if this customer represents a person, this is non-null
    store_id int null,  -- if the customer is a store, or is associated with a store then this is non-null.
    territory_id int null,
    account_number varchar, -- as isnull('aw' + dbo.ufn_leading_zeros(customer_id), ''),
    rowguid uuid not null constraint "df_customer_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_customer_modified_date" default (now())
  )
  create table person_credit_card(
    business_entity_id int not null,
    credit_card_id int not null,
    modified_date timestamp not null constraint "df_person_credit_card_modified_date" default (now())
  )
  create table sales_order_detail(
    sales_order_id int not null,
    sales_order_detail_id serial not null, -- int
    carrier_tracking_number varchar(25) null,
    order_qty smallint not null,
    product_id int not null,
    special_offer_id int not null,
    unit_price numeric not null, -- money
    unit_price_discount numeric not null constraint "df_sales_order_detail_unit_price_discount" default (0.0), -- money
    line_total numeric, -- as isnull(unit_price * (1.0 - unit_price_discount) * order_qty, 0.0),
    rowguid uuid not null constraint "df_sales_order_detail_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_sales_order_detail_modified_date" default (now()),
    constraint "ck_sales_order_detail_order_qty" check (order_qty > 0),
    constraint "ck_sales_order_detail_unit_price" check (unit_price >= 0.00),
    constraint "ck_sales_order_detail_unit_price_discount" check (unit_price_discount >= 0.00)
  )
  create table sales_order_header(
    sales_order_id serial not null, --  not for replication -- int
    revision_number smallint not null constraint "df_sales_order_header_revision_number" default (0), -- tinyint
    order_date timestamp not null constraint "df_sales_order_header_order_date" default (now()),
    due_date timestamp not null,
    ship_date timestamp null,
    status smallint not null constraint "df_sales_order_header_status" default (1), -- tinyint
    online_order_flag "flag" not null constraint "df_sales_order_header_online_order_flag" default (true),
    sales_order_number varchar(23), -- as isnull(n'so' + convert(nvarchar(23), sales_order_id), n'*** error ***'),
    purchase_order_number "order_number" null,
    account_number "account_number" null,
    customer_id int not null,
    sales_person_id int null,
    territory_id int null,
    bill_to_address_id int not null,
    ship_to_address_id int not null,
    ship_method_id int not null,
    credit_card_id int null,
    credit_card_approval_code varchar(15) null,   
    currency_rate_id int null,
    sub_total numeric not null constraint "df_sales_order_header_sub_total" default (0.00), -- money
    tax_amt numeric not null constraint "df_sales_order_header_tax_amt" default (0.00), -- money
    freight numeric not null constraint "df_sales_order_header_freight" default (0.00), -- money
    total_due numeric, -- as isnull(sub_total + tax_amt + freight, 0),
    comment varchar(128) null,
    rowguid uuid not null constraint "df_sales_order_header_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_sales_order_header_modified_date" default (now()),
    constraint "ck_sales_order_header_status" check (status between 0 and 8),
    constraint "ck_sales_order_header_due_date" check (due_date >= order_date),
    constraint "ck_sales_order_header_ship_date" check ((ship_date >= order_date) or (ship_date is null)),
    constraint "ck_sales_order_header_sub_total" check (sub_total >= 0.00),
    constraint "ck_sales_order_header_tax_amt" check (tax_amt >= 0.00),
    constraint "ck_sales_order_header_freight" check (freight >= 0.00)
  )
  create table sales_order_header_sales_reason(
    sales_order_id int not null,
    sales_reason_id int not null,
    modified_date timestamp not null constraint "df_sales_order_header_sales_reason_modified_date" default (now())
  )
  create table sales_person(
    business_entity_id int not null,
    territory_id int null,
    sales_quota numeric null, -- money
    bonus numeric not null constraint "df_sales_person_bonus" default (0.00), -- money
    commission_pct numeric not null constraint "df_sales_person_commission_pct" default (0.00), -- smallmoney -- money
    sales_ytd numeric not null constraint "df_sales_person_sales_ytd" default (0.00), -- money
    sales_last_year numeric not null constraint "df_sales_person_sales_last_year" default (0.00), -- money
    rowguid uuid not null constraint "df_sales_person_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_sales_person_modified_date" default (now()),
    constraint "ck_sales_person_sales_quota" check (sales_quota > 0.00),
    constraint "ck_sales_person_bonus" check (bonus >= 0.00),
    constraint "ck_sales_person_commission_pct" check (commission_pct >= 0.00),
    constraint "ck_sales_person_sales_ytd" check (sales_ytd >= 0.00),
    constraint "ck_sales_person_sales_last_year" check (sales_last_year >= 0.00)
  )
  create table sales_person_quota_history(
    business_entity_id int not null,
    quota_date timestamp not null,
    sales_quota numeric not null, -- money
    rowguid uuid not null constraint "df_sales_person_quota_history_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_sales_person_quota_history_modified_date" default (now()),
    constraint "ck_sales_person_quota_history_sales_quota" check (sales_quota > 0.00)
  )
  create table sales_reason(
    sales_reason_id serial not null, -- int
    name "name" not null,
    reason_type "name" not null,
    modified_date timestamp not null constraint "df_sales_reason_modified_date" default (now())
  )
  create table sales_tax_rate(
    sales_tax_rate_id serial not null, -- int
    state_province_id int not null,
    tax_type smallint not null, -- tinyint
    tax_rate numeric not null constraint "df_sales_tax_rate_tax_rate" default (0.00), -- smallmoney -- money
    name "name" not null,
    rowguid uuid not null constraint "df_sales_tax_rate_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_sales_tax_rate_modified_date" default (now()),
    constraint "ck_sales_tax_rate_tax_type" check (tax_type between 1 and 3)
  )
  create table sales_territory(
    territory_id serial not null, -- int
    name "name" not null,
    country_region_code varchar(3) not null,
    "group" varchar(50) not null, -- group
    sales_ytd numeric not null constraint "df_sales_territory_sales_ytd" default (0.00), -- money
    sales_last_year numeric not null constraint "df_sales_territory_sales_last_year" default (0.00), -- money
    cost_ytd numeric not null constraint "df_sales_territory_cost_ytd" default (0.00), -- money
    cost_last_year numeric not null constraint "df_sales_territory_cost_last_year" default (0.00), -- money
    rowguid uuid not null constraint "df_sales_territory_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_sales_territory_modified_date" default (now()),
    constraint "ck_sales_territory_sales_ytd" check (sales_ytd >= 0.00),
    constraint "ck_sales_territory_sales_last_year" check (sales_last_year >= 0.00),
    constraint "ck_sales_territory_cost_ytd" check (cost_ytd >= 0.00),
    constraint "ck_sales_territory_cost_last_year" check (cost_last_year >= 0.00)
  )
  create table sales_territory_history(
    business_entity_id int not null,  -- a sales person
    territory_id int not null,
    start_date timestamp not null,
    end_date timestamp null,
    rowguid uuid not null constraint "df_sales_territory_history_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_sales_territory_history_modified_date" default (now()),
    constraint "ck_sales_territory_history_end_date" check ((end_date >= start_date) or (end_date is null))
  )
  create table shopping_cart_item(
    shopping_cart_item_id serial not null, -- int
    shopping_cart_id varchar(50) not null,
    quantity int not null constraint "df_shopping_cart_item_quantity" default (1),
    product_id int not null,
    date_created timestamp not null constraint "df_shopping_cart_item_date_created" default (now()),
    modified_date timestamp not null constraint "df_shopping_cart_item_modified_date" default (now()),
    constraint "ck_shopping_cart_item_quantity" check (quantity >= 1)
  )
  create table special_offer(
    special_offer_id serial not null, -- int
    description varchar(255) not null,
    discount_pct numeric not null constraint "df_special_offer_discount_pct" default (0.00), -- smallmoney -- money
    type varchar(50) not null,
    category varchar(50) not null,
    start_date timestamp not null,
    end_date timestamp not null,
    min_qty int not null constraint "df_special_offer_min_qty" default (0),
    max_qty int null,
    rowguid uuid not null constraint "df_special_offer_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_special_offer_modified_date" default (now()),
    constraint "ck_special_offer_end_date" check (end_date >= start_date),
    constraint "ck_special_offer_discount_pct" check (discount_pct >= 0.00),
    constraint "ck_special_offer_min_qty" check (min_qty >= 0),
    constraint "ck_special_offer_max_qty"  check (max_qty >= 0)
  )
  create table special_offer_product(
    special_offer_id int not null,
    product_id int not null,
    rowguid uuid not null constraint "df_special_offer_product_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_special_offer_product_modified_date" default (now())
  )
  create table store(
    business_entity_id int not null,
    name "name" not null,
    sales_person_id int null,
    demographics xml null, -- xml(sales.store_survey_schema_collection)
    rowguid uuid not null constraint "df_store_rowguid" default (uuid_generate_v1()), -- rowguidcol
    modified_date timestamp not null constraint "df_store_modified_date" default (now())
  );

comment on schema sales is 'contains objects related to customers, sales orders, and sales territories.';

SELECT 'Copying data into sales.country_region_currency';
\copy sales.country_region_currency FROM 'CountryRegionCurrency.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.credit_card';
\copy sales.credit_card FROM 'CreditCard.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.currency';
\copy sales.currency FROM 'Currency.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.currency_rate';
\copy sales.currency_rate FROM 'CurrencyRate.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.customer';
\copy sales.customer FROM 'Customer.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.person_credit_card';
\copy sales.person_credit_card FROM 'PersonCreditCard.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_order_detail';
\copy sales.sales_order_detail FROM 'SalesOrderDetail.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_order_header';
\copy sales.sales_order_header FROM 'SalesOrderHeader.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_order_header_sales_reason';
\copy sales.sales_order_header_sales_reason FROM 'SalesOrderHeaderSalesReason.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_person';
\copy sales.sales_person FROM 'SalesPerson.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_person_quota_history';
\copy sales.sales_person_quota_history FROM 'SalesPersonQuotaHistory.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_reason';
\copy sales.sales_reason FROM 'SalesReason.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_tax_rate';
\copy sales.sales_tax_rate FROM 'SalesTaxRate.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_territory';
\copy sales.sales_territory FROM 'SalesTerritory.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.sales_territory_history';
\copy sales.sales_territory_history FROM 'SalesTerritoryHistory.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.shopping_cart_item';
\copy sales.shopping_cart_item FROM 'ShoppingCartItem.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.special_offer';
\copy sales.special_offer FROM 'SpecialOffer.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.special_offer_product';
\copy sales.special_offer_product FROM 'SpecialOfferProduct.csv' DELIMITER E'\t' CSV;
SELECT 'Copying data into sales.store';
\copy sales.store FROM 'Store.csv' DELIMITER E'\t' CSV;
-- Calculated columns that needed to be there just for the CSV import
alter table sales.customer drop column account_number;
alter table sales.sales_order_detail drop column line_total;
alter table sales.sales_order_header drop column sales_order_number;



-------------------------------------
-- TABLE AND COLUMN COMMENTS
-------------------------------------

set client_encoding=latin1;

-- COMMENT ON TABLE dbo.AWBuildVersion IS 'Current version number of the AdventureWorks2012_CS sample database.';
--   COMMENT ON COLUMN dbo.AWBuildVersion.SystemInformationID IS 'Primary key for AWBuildVersion records.';
--   COMMENT ON COLUMN AWBui.COLU.Version IS 'Version number of the database in 9.yy.mm.dd.00 format.';
--   COMMENT ON COLUMN dbo.AWBuildVersion.VersionDate IS 'Date and time the record was last updated.';

-- COMMENT ON TABLE dbo.DatabaseLog IS 'Audit table tracking all DDL changes made to the AdventureWorks database. Data is captured by the database trigger ddlDatabaseTriggerLog.';
--   COMMENT ON COLUMN dbo.DatabaseLog.PostTime IS 'The date and time the DDL change occurred.';
--   COMMENT ON COLUMN dbo.DatabaseLog.DatabaseUser IS 'The user who implemented the DDL change.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Event IS 'The type of DDL statement that was executed.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Schema IS 'The schema to which the changed object belongs.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Object IS 'The object that was changed by the DDL statment.';
--   COMMENT ON COLUMN dbo.DatabaseLog.TSQL IS 'The exact Transact-SQL statement that was executed.';
--   COMMENT ON COLUMN dbo.DatabaseLog.XmlEvent IS 'The raw XML data generated by database trigger.';

-- COMMENT ON TABLE dbo.ErrorLog IS 'Audit table tracking errors in the the AdventureWorks database that are caught by the CATCH block of a TRY...CATCH construct. Data is inserted by stored procedure dbo.uspLogError when it is executed from inside the CATCH block of a TRY...CATCH construct.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorLogID IS 'Primary key for ErrorLog records.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorTime IS 'The date and time at which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.UserName IS 'The user who executed the batch in which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorNumber IS 'The error number of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorSeverity IS 'The severity of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorState IS 'The state number of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorProcedure IS 'The name of the stored procedure or trigger where the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorLine IS 'The line number at which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorMessage IS 'The message text of the error that occurred.';

comment on table person.address is 'street address information for customers, employees, and vendors.';
  comment on column person.address.address_id is 'primary key for address records.';
  comment on column person.address.address_line1 is 'first street address line.';
  comment on column person.address.address_line2 is 'second street address line.';
  comment on column person.address.city is 'name of the city.';
  comment on column person.address.state_province_id is 'unique identification number for the state or province. foreign key to state_province table.';
  comment on column person.address.postal_code is 'postal code for the street address.';
  comment on column person.address.spatial_location is 'latitude and longitude of this address.';

comment on table person.address_type is 'types of addresses stored in the address table.';
  comment on column person.address_type.address_type_id is 'primary key for address_type records.';
  comment on column person.address_type.name is 'address type description. for example, billing, home, or shipping.';

comment on table production.bill_of_materials is 'items required to make bicycles and bicycle subassemblies. it identifies the heirarchical relationship between a parent product and its components.';
  comment on column production.bill_of_materials.bill_of_materials_id is 'primary key for bill_of_materials records.';
  comment on column production.bill_of_materials.product_assembly_id is 'parent product identification number. foreign key to product.product_id.';
  comment on column production.bill_of_materials.component_id is 'component identification number. foreign key to product.product_id.';
  comment on column production.bill_of_materials.start_date is 'date the component started being used in the assembly item.';
  comment on column production.bill_of_materials.end_date is 'date the component stopped being used in the assembly item.';
  comment on column production.bill_of_materials.unit_measure_code is 'standard code identifying the unit of measure for the quantity.';
  comment on column production.bill_of_materials.bom_level is 'indicates the depth the component is from its parent (assembly_id).';
  comment on column production.bill_of_materials.per_assembly_qty is 'quantity of the component needed to create the assembly.';

comment on table person.business_entity is 'source of the id that connects vendors, customers, and employees with address and contact information.';
  comment on column person.business_entity.business_entity_id is 'primary key for all customers, vendors, and employees.';

comment on table person.business_entity_address is 'cross-reference table mapping customers, vendors, and employees to their addresses.';
  comment on column person.business_entity_address.business_entity_id is 'primary key. foreign key to business_entity.business_entity_id.';
  comment on column person.business_entity_address.address_id is 'primary key. foreign key to address.address_id.';
  comment on column person.business_entity_address.address_type_id is 'primary key. foreign key to address_type.address_type_id.';

comment on table person.business_entity_contact is 'cross-reference table mapping stores, vendors, and employees to people';
  comment on column person.business_entity_contact.business_entity_id is 'primary key. foreign key to business_entity.business_entity_id.';
  comment on column person.business_entity_contact.person_id is 'primary key. foreign key to person.business_entity_id.';
  comment on column person.business_entity_contact.contact_type_id is 'primary key.  foreign key to contact_type.contact_type_id.';

comment on table person.contact_type is 'lookup table containing the types of business entity contacts.';
  comment on column person.contact_type.contact_type_id is 'primary key for contact_type records.';
  comment on column person.contact_type.name is 'contact type description.';

comment on table sales.country_region_currency is 'cross-reference table mapping iso currency codes to a country or region.';
  comment on column sales.country_region_currency.country_region_code is 'iso code for countries and regions. foreign key to country_region.country_region_code.';
  comment on column sales.country_region_currency.currency_code is 'iso standard currency code. foreign key to currency.currency_code.';

comment on table person.country_region is 'lookup table containing the iso standard codes for countries and regions.';
  comment on column person.country_region.country_region_code is 'iso standard code for countries and regions.';
  comment on column person.country_region.name is 'country or region name.';

comment on table sales.credit_card is 'customer credit card information.';
  comment on column sales.credit_card.credit_card_id is 'primary key for credit_card records.';
  comment on column sales.credit_card.card_type is 'credit card name.';
  comment on column sales.credit_card.card_number is 'credit card number.';
  comment on column sales.credit_card.exp_month is 'credit card expiration month.';
  comment on column sales.credit_card.exp_year is 'credit card expiration year.';

comment on table production.culture is 'lookup table containing the languages in which some adventure_works data is stored.';
  comment on column production.culture.culture_id is 'primary key for culture records.';
  comment on column production.culture.name is 'culture description.';

comment on table sales.currency is 'lookup table containing standard iso currencies.';
  comment on column sales.currency.currency_code is 'the iso code for the currency.';
  comment on column sales.currency.name is 'currency name.';

comment on table sales.currency_rate is 'currency exchange rates.';
  comment on column sales.currency_rate.currency_rate_id is 'primary key for currency_rate records.';
  comment on column sales.currency_rate.currency_rate_date is 'date and time the exchange rate was obtained.';
  comment on column sales.currency_rate.from_currency_code is 'exchange rate was converted from this currency code.';
  comment on column sales.currency_rate.to_currency_code is 'exchange rate was converted to this currency code.';
  comment on column sales.currency_rate.average_rate is 'average exchange rate for the day.';
  comment on column sales.currency_rate.end_of_day_rate is 'final exchange rate for the day.';

comment on table sales.customer is 'current customer information. also see the person and store tables.';
  comment on column sales.customer.customer_id is 'primary key.';
  comment on column sales.customer.person_id is 'foreign key to person.business_entity_id';
  comment on column sales.customer.store_id is 'foreign key to store.business_entity_id';
  comment on column sales.customer.territory_id is 'id of the territory in which the customer is located. foreign key to sales_territory.sales_territory_id.';
--  COMMENT ON COLUMN Sales.Customer.AccountNumber IS 'Unique number identifying the customer assigned by the accounting system.';

comment on table human_resources.department is 'lookup table containing the departments within the adventure works cycles company.';
  comment on column human_resources.department.department_id is 'primary key for department records.';
  comment on column human_resources.department.name is 'name of the department.';
  comment on column human_resources.department.group_name is 'name of the group to which the department belongs.';

comment on table production.document is 'product maintenance documents.';
  comment on column production.document.document_node is 'primary key for document records.';
--  COMMENT ON COLUMN Production.Document.DocumentLevel IS 'Depth in the document hierarchy.';
  comment on column production.document.title is 'title of the document.';
  comment on column production.document.owner is 'employee who controls the document.  foreign key to employee.business_entity_id';
  comment on column production.document.folder_flag is '0 = this is a folder, 1 = this is a document.';
  comment on column production.document.file_name is 'file name of the document';
  comment on column production.document.file_extension is 'file extension indicating the document type. for example, .doc or .txt.';
  comment on column production.document.revision is 'revision number of the document.';
  comment on column production.document.change_number is 'engineering change approval number.';
  comment on column production.document.status is '1 = pending approval, 2 = approved, 3 = obsolete';
  comment on column production.document.document_summary is 'document abstract.';
  comment on column production.document.document is 'complete document.';
  comment on column production.document.rowguid is 'rowguidcol number uniquely identifying the record. required for file_stream.';

comment on table person.email_address is 'where to send a person email.';
  comment on column person.email_address.business_entity_id is 'primary key. person associated with this email address.  foreign key to person.business_entity_id';
  comment on column person.email_address.email_address_id is 'primary key. id of this email address.';
  comment on column person.email_address.email_address is 'e-mail address for the person.';

comment on table human_resources.employee is 'employee information such as salary, department, and title.';
  comment on column human_resources.employee.business_entity_id is 'primary key for employee records.  foreign key to business_entity.business_entity_id.';
  comment on column human_resources.employee.national_id_number is 'unique national identification number such as a social security number.';
  comment on column human_resources.employee.login_id is 'network login.';
  comment on column human_resources.employee.organization_node is 'where the employee is located in corporate hierarchy.';
--  COMMENT ON COLUMN HumanResources.Employee.OrganizationLevel IS 'The depth of the employee in the corporate hierarchy.';
  comment on column human_resources.employee.job_title is 'work title such as buyer or sales representative.';
  comment on column human_resources.employee.birth_date is 'date of birth.';
  comment on column human_resources.employee.marital_status is 'm = married, s = single';
  comment on column human_resources.employee.gender is 'm = male, f = female';
  comment on column human_resources.employee.hire_date is 'employee hired on this date.';
  comment on column human_resources.employee.salaried_flag is 'job classification. 0 = hourly, not exempt from collective bargaining. 1 = salaried, exempt from collective bargaining.';
  comment on column human_resources.employee.vacation_hours is 'number of available vacation hours.';
  comment on column human_resources.employee.sick_leave_hours is 'number of available sick leave hours.';
  comment on column human_resources.employee.current_flag is '0 = inactive, 1 = active';

comment on table human_resources.employee_department_history is 'employee department transfers.';
  comment on column human_resources.employee_department_history.business_entity_id is 'employee identification number. foreign key to employee.business_entity_id.';
  comment on column human_resources.employee_department_history.department_id is 'department in which the employee worked including currently. foreign key to department.department_id.';
  comment on column human_resources.employee_department_history.shift_id is 'identifies which 8-hour shift the employee works. foreign key to shift.shift.id.';
  comment on column human_resources.employee_department_history.start_date is 'date the employee started work in the department.';
  comment on column human_resources.employee_department_history.end_date is 'date the employee left the department. null = current department.';

comment on table human_resources.employee_pay_history is 'employee pay history.';
  comment on column human_resources.employee_pay_history.business_entity_id is 'employee identification number. foreign key to employee.business_entity_id.';
  comment on column human_resources.employee_pay_history.rate_change_date is 'date the change in pay is effective';
  comment on column human_resources.employee_pay_history.rate is 'salary hourly rate.';
  comment on column human_resources.employee_pay_history.pay_frequency is '1 = salary received monthly, 2 = salary received biweekly';

comment on table production.illustration is 'bicycle assembly diagrams.';
  comment on column production.illustration.illustration_id is 'primary key for illustration records.';
  comment on column production.illustration.diagram is 'illustrations used in manufacturing instructions. stored as xml.';

comment on table human_resources.job_candidate is 'résumés submitted to human resources by job applicants.';
  comment on column human_resources.job_candidate.job_candidate_id is 'primary key for job_candidate records.';
  comment on column human_resources.job_candidate.business_entity_id is 'employee identification number if applicant was hired. foreign key to employee.business_entity_id.';
  comment on column human_resources.job_candidate.resume is 'résumé in xml format.';

comment on table production.location is 'product inventory and manufacturing locations.';
  comment on column production.location.location_id is 'primary key for location records.';
  comment on column production.location.name is 'location description.';
  comment on column production.location.cost_rate is 'standard hourly cost of the manufacturing location.';
  comment on column production.location.availability is 'work capacity (in hours) of the manufacturing location.';

comment on table person.password is 'one way hashed authentication information';
  comment on column person.password.password_hash is 'password for the e-mail account.';
  comment on column person.password.password_salt is 'random value concatenated with the password string before the password is hashed.';

comment on table person.person is 'human beings involved with adventure_works: employees, customer contacts, and vendor contacts.';
  comment on column person.person.business_entity_id is 'primary key for person records.';
  comment on column person.person.person_type is 'primary type of person: sc = store contact, in = individual (retail) customer, sp = sales person, em = employee (non-sales), vc = vendor contact, gc = general contact';
  comment on column person.person.name_style is '0 = the data in first_name and last_name are stored in western style (first name, last name) order.  1 = eastern style (last name, first name) order.';
  comment on column person.person.title is 'a courtesy title. for example, mr. or ms.';
  comment on column person.person.first_name is 'first name of the person.';
  comment on column person.person.middle_name is 'middle name or middle initial of the person.';
  comment on column person.person.last_name is 'last name of the person.';
  comment on column person.person.suffix is 'surname suffix. for example, sr. or jr.';
  comment on column person.person.email_promotion is '0 = contact does not wish to receive e-mail promotions, 1 = contact does wish to receive e-mail promotions from adventure_works, 2 = contact does wish to receive e-mail promotions from adventure_works and selected partners.';
  comment on column person.person.demographics is 'personal information such as hobbies, and income collected from online shoppers. used for sales analysis.';
  comment on column person.person.additional_contact_info is 'additional contact information about the person stored in xml format.';

comment on table sales.person_credit_card is 'cross-reference table mapping people to their credit card information in the credit_card table.';
  comment on column sales.person_credit_card.business_entity_id is 'business entity identification number. foreign key to person.business_entity_id.';
  comment on column sales.person_credit_card.credit_card_id is 'credit card identification number. foreign key to credit_card.credit_card_id.';

comment on table person.person_phone is 'telephone number and type of a person.';
  comment on column person.person_phone.business_entity_id is 'business entity identification number. foreign key to person.business_entity_id.';
  comment on column person.person_phone.phone_number is 'telephone number identification number.';
  comment on column person.person_phone.phone_number_type_id is 'kind of phone number. foreign key to phone_number_type.phone_number_type_id.';

comment on table person.phone_number_type is 'type of phone number of a person.';
  comment on column person.phone_number_type.phone_number_type_id is 'primary key for telephone number type records.';
  comment on column person.phone_number_type.name is 'name of the telephone number type';

comment on table production.product is 'products sold or used in the manfacturing of sold products.';
  comment on column production.product.product_id is 'primary key for product records.';
  comment on column production.product.name is 'name of the product.';
  comment on column production.product.product_number is 'unique product identification number.';
  comment on column production.product.make_flag is '0 = product is purchased, 1 = product is manufactured in-house.';
  comment on column production.product.finished_goods_flag is '0 = product is not a salable item. 1 = product is salable.';
  comment on column production.product.color is 'product color.';
  comment on column production.product.safety_stock_level is 'minimum inventory quantity.';
  comment on column production.product.reorder_point is 'inventory level that triggers a purchase order or work order.';
  comment on column production.product.standard_cost is 'standard cost of the product.';
  comment on column production.product.list_price is 'selling price.';
  comment on column production.product.size is 'product size.';
  comment on column production.product.size_unit_measure_code is 'unit of measure for size column.';
  comment on column production.product.weight_unit_measure_code is 'unit of measure for weight column.';
  comment on column production.product.weight is 'product weight.';
  comment on column production.product.days_to_manufacture is 'number of days required to manufacture the product.';
  comment on column production.product.product_line is 'r = road, m = mountain, t = touring, s = standard';
  comment on column production.product.class is 'h = high, m = medium, l = low';
  comment on column production.product.style is 'w = womens, m = mens, u = universal';
  comment on column production.product.product_subcategory_id is 'product is a member of this product subcategory. foreign key to product_sub_category.product_sub_category_id.';
  comment on column production.product.product_model_id is 'product is a member of this product model. foreign key to product_model.product_model_id.';
  comment on column production.product.sell_start_date is 'date the product was available for sale.';
  comment on column production.product.sell_end_date is 'date the product was no longer available for sale.';
  comment on column production.product.discontinued_date is 'date the product was discontinued.';

comment on table production.product_category is 'high-level product categorization.';
  comment on column production.product_category.product_category_id is 'primary key for product_category records.';
  comment on column production.product_category.name is 'category description.';

comment on table production.product_cost_history is 'changes in the cost of a product over time.';
  comment on column production.product_cost_history.product_id is 'product identification number. foreign key to product.product_id';
  comment on column production.product_cost_history.start_date is 'product cost start date.';
  comment on column production.product_cost_history.end_date is 'product cost end date.';
  comment on column production.product_cost_history.standard_cost is 'standard cost of the product.';

comment on table production.product_description is 'product descriptions in several languages.';
  comment on column production.product_description.product_description_id is 'primary key for product_description records.';
  comment on column production.product_description.description is 'description of the product.';

comment on table production.product_document is 'cross-reference table mapping products to related product documents.';
  comment on column production.product_document.product_id is 'product identification number. foreign key to product.product_id.';
  comment on column production.product_document.document_node is 'document identification number. foreign key to document.document_node.';

comment on table production.product_inventory is 'product inventory information.';
  comment on column production.product_inventory.product_id is 'product identification number. foreign key to product.product_id.';
  comment on column production.product_inventory.location_id is 'inventory location identification number. foreign key to location.location_id.';
  comment on column production.product_inventory.shelf is 'storage compartment within an inventory location.';
  comment on column production.product_inventory.bin is 'storage container on a shelf in an inventory location.';
  comment on column production.product_inventory.quantity is 'quantity of products in the inventory location.';

comment on table production.product_list_price_history is 'changes in the list price of a product over time.';
  comment on column production.product_list_price_history.product_id is 'product identification number. foreign key to product.product_id';
  comment on column production.product_list_price_history.start_date is 'list price start date.';
  comment on column production.product_list_price_history.end_date is 'list price end date';
  comment on column production.product_list_price_history.list_price is 'product list price.';

comment on table production.product_model is 'product model classification.';
  comment on column production.product_model.product_model_id is 'primary key for product_model records.';
  comment on column production.product_model.name is 'product model description.';
  comment on column production.product_model.catalog_description is 'detailed product catalog information in xml format.';
  comment on column production.product_model.instructions is 'manufacturing instructions in xml format.';

comment on table production.product_model_illustration is 'cross-reference table mapping product models and illustrations.';
  comment on column production.product_model_illustration.product_model_id is 'primary key. foreign key to product_model.product_model_id.';
  comment on column production.product_model_illustration.illustration_id is 'primary key. foreign key to illustration.illustration_id.';

comment on table production.product_model_product_description_culture is 'cross-reference table mapping product descriptions and the language the description is written in.';
  comment on column production.product_model_product_description_culture.product_model_id is 'primary key. foreign key to product_model.product_model_id.';
  comment on column production.product_model_product_description_culture.product_description_id is 'primary key. foreign key to product_description.product_description_id.';
  comment on column production.product_model_product_description_culture.culture_id is 'culture identification number. foreign key to culture.culture_id.';

comment on table production.product_photo is 'product images.';
  comment on column production.product_photo.product_photo_id is 'primary key for product_photo records.';
  comment on column production.product_photo.thumb_nail_photo is 'small image of the product.';
  comment on column production.product_photo.thumbnail_photo_file_name is 'small image file name.';
  comment on column production.product_photo.large_photo is 'large image of the product.';
  comment on column production.product_photo.large_photo_file_name is 'large image file name.';

comment on table production.product_product_photo is 'cross-reference table mapping products and product photos.';
  comment on column production.product_product_photo.product_id is 'product identification number. foreign key to product.product_id.';
  comment on column production.product_product_photo.product_photo_id is 'product photo identification number. foreign key to product_photo.product_photo_id.';
  comment on column production.product_product_photo.primary is '0 = photo is not the principal image. 1 = photo is the principal image.';

comment on table production.product_review is 'customer reviews of products they have purchased.';
  comment on column production.product_review.product_review_id is 'primary key for product_review records.';
  comment on column production.product_review.product_id is 'product identification number. foreign key to product.product_id.';
  comment on column production.product_review.reviewer_name is 'name of the reviewer.';
  comment on column production.product_review.review_date is 'date review was submitted.';
  comment on column production.product_review.email_address is 'reviewer''s e-mail address.';
  comment on column production.product_review.rating is 'product rating given by the reviewer. scale is 1 to 5 with 5 as the highest rating.';
  comment on column production.product_review.comments is 'reviewer''s comments';

comment on table production.product_subcategory is 'product subcategories. see product_category table.';
  comment on column production.product_subcategory.product_subcategory_id is 'primary key for product_subcategory records.';
  comment on column production.product_subcategory.product_category_id is 'product category identification number. foreign key to product_category.product_category_id.';
  comment on column production.product_subcategory.name is 'subcategory description.';

comment on table purchasing.product_vendor is 'cross-reference table mapping vendors with the products they supply.';
  comment on column purchasing.product_vendor.product_id is 'primary key. foreign key to product.product_id.';
  comment on column purchasing.product_vendor.business_entity_id is 'primary key. foreign key to vendor.business_entity_id.';
  comment on column purchasing.product_vendor.average_lead_time is 'the average span of time (in days) between placing an order with the vendor and receiving the purchased product.';
  comment on column purchasing.product_vendor.standard_price is 'the vendor''s usual selling price.';
  comment on column purchasing.product_vendor.last_receipt_cost is 'the selling price when last purchased.';
  comment on column purchasing.product_vendor.last_receipt_date is 'date the product was last received by the vendor.';
  comment on column purchasing.product_vendor.min_order_qty is 'the maximum quantity that should be ordered.';
  comment on column purchasing.product_vendor.max_order_qty is 'the minimum quantity that should be ordered.';
  comment on column purchasing.product_vendor.on_order_qty is 'the quantity currently on order.';
  comment on column purchasing.product_vendor.unit_measure_code is 'the product''s unit of measure.';

comment on table purchasing.purchase_order_detail is 'individual products associated with a specific purchase order. see purchase_order_header.';
  comment on column purchasing.purchase_order_detail.purchase_order_id is 'primary key. foreign key to purchase_order_header.purchase_order_id.';
  comment on column purchasing.purchase_order_detail.purchase_order_detail_id is 'primary key. one line number per purchased product.';
  comment on column purchasing.purchase_order_detail.due_date is 'date the product is expected to be received.';
  comment on column purchasing.purchase_order_detail.order_qty is 'quantity ordered.';
  comment on column purchasing.purchase_order_detail.product_id is 'product identification number. foreign key to product.product_id.';
  comment on column purchasing.purchase_order_detail.unit_price is 'vendor''s selling price of a single product.';
--  COMMENT ON COLUMN Purchasing.PurchaseOrderDetail.LineTotal IS 'Per product subtotal. Computed as OrderQty * UnitPrice.';
  comment on column purchasing.purchase_order_detail.received_qty is 'quantity actually received from the vendor.';
  comment on column purchasing.purchase_order_detail.rejected_qty is 'quantity rejected during inspection.';
--  COMMENT ON COLUMN Purchasing.PurchaseOrderDetail.StockedQty IS 'Quantity accepted into inventory. Computed as ReceivedQty - RejectedQty.';

comment on table purchasing.purchase_order_header is 'general purchase order information. see purchase_order_detail.';
  comment on column purchasing.purchase_order_header.purchase_order_id is 'primary key.';
  comment on column purchasing.purchase_order_header.revision_number is 'incremental number to track changes to the purchase order over time.';
  comment on column purchasing.purchase_order_header.status is 'order current status. 1 = pending; 2 = approved; 3 = rejected; 4 = complete';
  comment on column purchasing.purchase_order_header.employee_id is 'employee who created the purchase order. foreign key to employee.business_entity_id.';
  comment on column purchasing.purchase_order_header.vendor_id is 'vendor with whom the purchase order is placed. foreign key to vendor.business_entity_id.';
  comment on column purchasing.purchase_order_header.ship_method_id is 'shipping method. foreign key to ship_method.ship_method_id.';
  comment on column purchasing.purchase_order_header.order_date is 'purchase order creation date.';
  comment on column purchasing.purchase_order_header.ship_date is 'estimated shipment date from the vendor.';
  comment on column purchasing.purchase_order_header.sub_total is 'purchase order subtotal. computed as sum(purchase_order_detail.line_total)for the appropriate purchase_order_id.';
  comment on column purchasing.purchase_order_header.tax_amt is 'tax amount.';
  comment on column purchasing.purchase_order_header.freight is 'shipping cost.';
--  COMMENT ON COLUMN Purchasing.PurchaseOrderHeader.TotalDue IS 'Total due to vendor. Computed as Subtotal + TaxAmt + Freight.';

comment on table sales.sales_order_detail is 'individual products associated with a specific sales order. see sales_order_header.';
  comment on column sales.sales_order_detail.sales_order_id is 'primary key. foreign key to sales_order_header.sales_order_id.';
  comment on column sales.sales_order_detail.sales_order_detail_id is 'primary key. one incremental unique number per product sold.';
  comment on column sales.sales_order_detail.carrier_tracking_number is 'shipment tracking number supplied by the shipper.';
  comment on column sales.sales_order_detail.order_qty is 'quantity ordered per product.';
  comment on column sales.sales_order_detail.product_id is 'product sold to customer. foreign key to product.product_id.';
  comment on column sales.sales_order_detail.special_offer_id is 'promotional code. foreign key to special_offer.special_offer_id.';
  comment on column sales.sales_order_detail.unit_price is 'selling price of a single product.';
  comment on column sales.sales_order_detail.unit_price_discount is 'discount amount.';
--  COMMENT ON COLUMN Sales.SalesOrderDetail.LineTotal IS 'Per product subtotal. Computed as UnitPrice * (1 - UnitPriceDiscount) * OrderQty.';

comment on table sales.sales_order_header is 'general sales order information.';
  comment on column sales.sales_order_header.sales_order_id is 'primary key.';
  comment on column sales.sales_order_header.revision_number is 'incremental number to track changes to the sales order over time.';
  comment on column sales.sales_order_header.order_date is 'dates the sales order was created.';
  comment on column sales.sales_order_header.due_date is 'date the order is due to the customer.';
  comment on column sales.sales_order_header.ship_date is 'date the order was shipped to the customer.';
  comment on column sales.sales_order_header.status is 'order current status. 1 = in process; 2 = approved; 3 = backordered; 4 = rejected; 5 = shipped; 6 = cancelled';
  comment on column sales.sales_order_header.online_order_flag is '0 = order placed by sales person. 1 = order placed online by customer.';
--  COMMENT ON COLUMN Sales.SalesOrderHeader.SalesOrderNumber IS 'Unique sales order identification number.';
  comment on column sales.sales_order_header.purchase_order_number is 'customer purchase order number reference.';
  comment on column sales.sales_order_header.account_number is 'financial accounting number reference.';
  comment on column sales.sales_order_header.customer_id is 'customer identification number. foreign key to customer.business_entity_id.';
  comment on column sales.sales_order_header.sales_person_id is 'sales person who created the sales order. foreign key to sales_person.business_entity_id.';
  comment on column sales.sales_order_header.territory_id is 'territory in which the sale was made. foreign key to sales_territory.sales_territory_id.';
  comment on column sales.sales_order_header.bill_to_address_id is 'customer billing address. foreign key to address.address_id.';
  comment on column sales.sales_order_header.ship_to_address_id is 'customer shipping address. foreign key to address.address_id.';
  comment on column sales.sales_order_header.ship_method_id is 'shipping method. foreign key to ship_method.ship_method_id.';
  comment on column sales.sales_order_header.credit_card_id is 'credit card identification number. foreign key to credit_card.credit_card_id.';
  comment on column sales.sales_order_header.credit_card_approval_code is 'approval code provided by the credit card company.';
  comment on column sales.sales_order_header.currency_rate_id is 'currency exchange rate used. foreign key to currency_rate.currency_rate_id.';
  comment on column sales.sales_order_header.sub_total is 'sales subtotal. computed as sum(sales_order_detail.line_total)for the appropriate sales_order_id.';
  comment on column sales.sales_order_header.tax_amt is 'tax amount.';
  comment on column sales.sales_order_header.freight is 'shipping cost.';
  comment on column sales.sales_order_header.total_due is 'total due from customer. computed as subtotal + tax_amt + freight.';
  comment on column sales.sales_order_header.comment is 'sales representative comments.';

comment on table sales.sales_order_header_sales_reason is 'cross-reference table mapping sales orders to sales reason codes.';
  comment on column sales.sales_order_header_sales_reason.sales_order_id is 'primary key. foreign key to sales_order_header.sales_order_id.';
  comment on column sales.sales_order_header_sales_reason.sales_reason_id is 'primary key. foreign key to sales_reason.sales_reason_id.';

comment on table sales.sales_person is 'sales representative current information.';
  comment on column sales.sales_person.business_entity_id is 'primary key for sales_person records. foreign key to employee.business_entity_id';
  comment on column sales.sales_person.territory_id is 'territory currently assigned to. foreign key to sales_territory.sales_territory_id.';
  comment on column sales.sales_person.sales_quota is 'projected yearly sales.';
  comment on column sales.sales_person.bonus is 'bonus due if quota is met.';
  comment on column sales.sales_person.commission_pct is 'commision percent received per sale.';
  comment on column sales.sales_person.sales_ytd is 'sales total year to date.';
  comment on column sales.sales_person.sales_last_year is 'sales total of previous year.';

comment on table sales.sales_person_quota_history is 'sales performance tracking.';
  comment on column sales.sales_person_quota_history.business_entity_id is 'sales person identification number. foreign key to sales_person.business_entity_id.';
  comment on column sales.sales_person_quota_history.quota_date is 'sales quota date.';
  comment on column sales.sales_person_quota_history.sales_quota is 'sales quota amount.';

comment on table sales.sales_reason is 'lookup table of customer purchase reasons.';
  comment on column sales.sales_reason.sales_reason_id is 'primary key for sales_reason records.';
  comment on column sales.sales_reason.name is 'sales reason description.';
  comment on column sales.sales_reason.reason_type is 'category the sales reason belongs to.';

comment on table sales.sales_tax_rate is 'tax rate lookup table.';
  comment on column sales.sales_tax_rate.sales_tax_rate_id is 'primary key for sales_tax_rate records.';
  comment on column sales.sales_tax_rate.state_province_id is 'state, province, or country/region the sales tax applies to.';
  comment on column sales.sales_tax_rate.tax_type is '1 = tax applied to retail transactions, 2 = tax applied to wholesale transactions, 3 = tax applied to all sales (retail and wholesale) transactions.';
  comment on column sales.sales_tax_rate.tax_rate is 'tax rate amount.';
  comment on column sales.sales_tax_rate.name is 'tax rate description.';

comment on table sales.sales_territory is 'sales territory lookup table.';
  comment on column sales.sales_territory.territory_id is 'primary key for sales_territory records.';
  comment on column sales.sales_territory.name is 'sales territory description';
  comment on column sales.sales_territory.country_region_code is 'iso standard country or region code. foreign key to country_region.country_region_code.';
  comment on column sales.sales_territory.group is 'geographic area to which the sales territory belong.';
  comment on column sales.sales_territory.sales_ytd is 'sales in the territory year to date.';
  comment on column sales.sales_territory.sales_last_year is 'sales in the territory the previous year.';
  comment on column sales.sales_territory.cost_ytd is 'business costs in the territory year to date.';
  comment on column sales.sales_territory.cost_last_year is 'business costs in the territory the previous year.';

comment on table sales.sales_territory_history is 'sales representative transfers to other sales territories.';
  comment on column sales.sales_territory_history.business_entity_id is 'primary key. the sales rep.  foreign key to sales_person.business_entity_id.';
  comment on column sales.sales_territory_history.territory_id is 'primary key. territory identification number. foreign key to sales_territory.sales_territory_id.';
  comment on column sales.sales_territory_history.start_date is 'primary key. date the sales representive started work in the territory.';
  comment on column sales.sales_territory_history.end_date is 'date the sales representative left work in the territory.';

comment on table production.scrap_reason is 'manufacturing failure reasons lookup table.';
  comment on column production.scrap_reason.scrap_reason_id is 'primary key for scrap_reason records.';
  comment on column production.scrap_reason.name is 'failure description.';

comment on table human_resources.shift is 'work shift lookup table.';
  comment on column human_resources.shift.shift_id is 'primary key for shift records.';
  comment on column human_resources.shift.name is 'shift description.';
  comment on column human_resources.shift.start_time is 'shift start time.';
  comment on column human_resources.shift.end_time is 'shift end time.';

comment on table purchasing.ship_method is 'shipping company lookup table.';
  comment on column purchasing.ship_method.ship_method_id is 'primary key for ship_method records.';
  comment on column purchasing.ship_method.name is 'shipping company name.';
  comment on column purchasing.ship_method.ship_base is 'minimum shipping charge.';
  comment on column purchasing.ship_method.ship_rate is 'shipping charge per pound.';

comment on table sales.shopping_cart_item is 'contains online customer orders until the order is submitted or cancelled.';
  comment on column sales.shopping_cart_item.shopping_cart_item_id is 'primary key for shopping_cart_item records.';
  comment on column sales.shopping_cart_item.shopping_cart_id is 'shopping cart identification number.';
  comment on column sales.shopping_cart_item.quantity is 'product quantity ordered.';
  comment on column sales.shopping_cart_item.product_id is 'product ordered. foreign key to product.product_id.';
  comment on column sales.shopping_cart_item.date_created is 'date the time the record was created.';

comment on table sales.special_offer is 'sale discounts lookup table.';
  comment on column sales.special_offer.special_offer_id is 'primary key for special_offer records.';
  comment on column sales.special_offer.description is 'discount description.';
  comment on column sales.special_offer.discount_pct is 'discount precentage.';
  comment on column sales.special_offer.type is 'discount type category.';
  comment on column sales.special_offer.category is 'group the discount applies to such as reseller or customer.';
  comment on column sales.special_offer.start_date is 'discount start date.';
  comment on column sales.special_offer.end_date is 'discount end date.';
  comment on column sales.special_offer.min_qty is 'minimum discount percent allowed.';
  comment on column sales.special_offer.max_qty is 'maximum discount percent allowed.';

comment on table sales.special_offer_product is 'cross-reference table mapping products to special offer discounts.';
  comment on column sales.special_offer_product.special_offer_id is 'primary key for special_offer_product records.';
  comment on column sales.special_offer_product.product_id is 'product identification number. foreign key to product.product_id.';

comment on table person.state_province is 'state and province lookup table.';
  comment on column person.state_province.state_province_id is 'primary key for state_province records.';
  comment on column person.state_province.state_province_code is 'iso standard state or province code.';
  comment on column person.state_province.country_region_code is 'iso standard country or region code. foreign key to country_region.country_region_code.';
  comment on column person.state_province.is_only_state_province_flag is '0 = state_province_code exists. 1 = state_province_code unavailable, using country_region_code.';
  comment on column person.state_province.name is 'state or province description.';
  comment on column person.state_province.territory_id is 'id of the territory in which the state or province is located. foreign key to sales_territory.sales_territory_id.';

comment on table sales.store is 'customers (resellers) of adventure works products.';
  comment on column sales.store.business_entity_id is 'primary key. foreign key to customer.business_entity_id.';
  comment on column sales.store.name is 'name of the store.';
  comment on column sales.store.sales_person_id is 'id of the sales person assigned to the customer. foreign key to sales_person.business_entity_id.';
  comment on column sales.store.demographics is 'demographic informationg about the store such as the number of employees, annual sales and store type.';


comment on table production.transaction_history is 'record of each purchase order, sales order, or work order transaction year to date.';
  comment on column production.transaction_history.transaction_id is 'primary key for transaction_history records.';
  comment on column production.transaction_history.product_id is 'product identification number. foreign key to product.product_id.';
  comment on column production.transaction_history.reference_order_id is 'purchase order, sales order, or work order identification number.';
  comment on column production.transaction_history.reference_order_line_id is 'line number associated with the purchase order, sales order, or work order.';
  comment on column production.transaction_history.transaction_date is 'date and time of the transaction.';
  comment on column production.transaction_history.transaction_type is 'w = work_order, s = sales_order, p = purchase_order';
  comment on column production.transaction_history.quantity is 'product quantity.';
  comment on column production.transaction_history.actual_cost is 'product cost.';

comment on table production.transaction_history_archive is 'transactions for previous years.';
  comment on column production.transaction_history_archive.transaction_id is 'primary key for transaction_history_archive records.';
  comment on column production.transaction_history_archive.product_id is 'product identification number. foreign key to product.product_id.';
  comment on column production.transaction_history_archive.reference_order_id is 'purchase order, sales order, or work order identification number.';
  comment on column production.transaction_history_archive.reference_order_line_id is 'line number associated with the purchase order, sales order, or work order.';
  comment on column production.transaction_history_archive.transaction_date is 'date and time of the transaction.';
  comment on column production.transaction_history_archive.transaction_type is 'w = work order, s = sales order, p = purchase order';
  comment on column production.transaction_history_archive.quantity is 'product quantity.';
  comment on column production.transaction_history_archive.actual_cost is 'product cost.';

comment on table production.unit_measure is 'unit of measure lookup table.';
  comment on column production.unit_measure.unit_measure_code is 'primary key.';
  comment on column production.unit_measure.name is 'unit of measure description.';

comment on table purchasing.vendor is 'companies from whom adventure works cycles purchases parts or other goods.';
  comment on column purchasing.vendor.business_entity_id is 'primary key for vendor records.  foreign key to business_entity.business_entity_id';
  comment on column purchasing.vendor.account_number is 'vendor account (identification) number.';
  comment on column purchasing.vendor.name is 'company name.';
  comment on column purchasing.vendor.credit_rating is '1 = superior, 2 = excellent, 3 = above average, 4 = average, 5 = below average';
  comment on column purchasing.vendor.preferred_vendor_status is '0 = do not use if another vendor is available. 1 = preferred over other vendors supplying the same product.';
  comment on column purchasing.vendor.active_flag is '0 = vendor no longer used. 1 = vendor is actively used.';
  comment on column purchasing.vendor.purchasing_web_service_url is 'vendor url.';

comment on table production.work_order is 'manufacturing work orders.';
  comment on column production.work_order.work_order_id is 'primary key for work_order records.';
  comment on column production.work_order.product_id is 'product identification number. foreign key to product.product_id.';
  comment on column production.work_order.order_qty is 'product quantity to build.';
--  COMMENT ON COLUMN Production.WorkOrder.StockedQty IS 'Quantity built and put in inventory.';
  comment on column production.work_order.scrapped_qty is 'quantity that failed inspection.';
  comment on column production.work_order.start_date is 'work order start date.';
  comment on column production.work_order.end_date is 'work order end date.';
  comment on column production.work_order.due_date is 'work order due date.';
  comment on column production.work_order.scrap_reason_id is 'reason for inspection failure.';

comment on table production.work_order_routing is 'work order details.';
  comment on column production.work_order_routing.work_order_id is 'primary key. foreign key to work_order.work_order_id.';
  comment on column production.work_order_routing.product_id is 'primary key. foreign key to product.product_id.';
  comment on column production.work_order_routing.operation_sequence is 'primary key. indicates the manufacturing process sequence.';
  comment on column production.work_order_routing.location_id is 'manufacturing location where the part is processed. foreign key to location.location_id.';
  comment on column production.work_order_routing.scheduled_start_date is 'planned manufacturing start date.';
  comment on column production.work_order_routing.scheduled_end_date is 'planned manufacturing end date.';
  comment on column production.work_order_routing.actual_start_date is 'actual start date.';
  comment on column production.work_order_routing.actual_end_date is 'actual end date.';
  comment on column production.work_order_routing.actual_resource_hrs is 'number of manufacturing hours used.';
  comment on column production.work_order_routing.planned_cost is 'estimated manufacturing cost.';
  comment on column production.work_order_routing.actual_cost is 'actual manufacturing cost.';



-------------------------------------
-- PRIMARY KEYS
-------------------------------------

-- ALTER TABLE dbo.AWBuildVersion ADD
--     CONSTRAINT "PK_AWBuildVersion_SystemInformationID" PRIMARY KEY
--     (SystemInformationID);
-- CLUSTER dbo.AWBuildVersion USING "PK_AWBuildVersion_SystemInformationID";

-- ALTER TABLE dbo.DatabaseLog ADD
--     CONSTRAINT "PK_DatabaseLog_DatabaseLogID" PRIMARY KEY
--     (DatabaseLogID);

alter table person.address add
    constraint "pk_address_address_id" primary key
    (address_id);
cluster person.address using "pk_address_address_id";

alter table person.address_type add
    constraint "pk_address_type_address_type_id" primary key
    (address_type_id);
cluster person.address_type using "pk_address_type_address_type_id";

alter table production.bill_of_materials add
    constraint "pk_bill_of_materials_bill_of_materials_id" primary key
    (bill_of_materials_id);

alter table person.business_entity add
    constraint "pk_b_entity_business_entity_id" primary key
    (business_entity_id);
cluster person.business_entity using "pk_b_entity_business_entity_id";

alter table person.business_entity_address add
    constraint "pk_b_entity_address_b_entity_id_address_id_address_type" primary key
    (business_entity_id, address_id, address_type_id);
cluster person.business_entity_address using "pk_b_entity_address_b_entity_id_address_id_address_type";

alter table person.business_entity_contact add
    constraint "pk_b_entity_contact_b_entity_id_person_id_contact_type_id" primary key
    (business_entity_id, person_id, contact_type_id);
cluster person.business_entity_contact using "pk_b_entity_contact_b_entity_id_person_id_contact_type_id";

alter table person.contact_type add
    constraint "pk_contact_type_contact_type_id" primary key
    (contact_type_id);
cluster person.contact_type using "pk_contact_type_contact_type_id";

alter table sales.country_region_currency add
    constraint "pk_country_region_currency_country_region_code_currency_code" primary key
    (country_region_code, currency_code);
cluster sales.country_region_currency using "pk_country_region_currency_country_region_code_currency_code";

alter table person.country_region add
    constraint "pk_country_region_country_region_code" primary key
    (country_region_code);
cluster person.country_region using "pk_country_region_country_region_code";

alter table sales.credit_card add
    constraint "pk_credit_card_credit_card_id" primary key
    (credit_card_id);
cluster sales.credit_card using "pk_credit_card_credit_card_id";

alter table sales.currency add
    constraint "pk_currency_currency_code" primary key
    (currency_code);
cluster sales.currency using "pk_currency_currency_code";

alter table sales.currency_rate add
    constraint "pk_currency_rate_currency_rate_id" primary key
    (currency_rate_id);
cluster sales.currency_rate using "pk_currency_rate_currency_rate_id";

alter table sales.customer add
    constraint "pk_customer_customer_id" primary key
    (customer_id);
cluster sales.customer using "pk_customer_customer_id";

alter table production.culture add
    constraint "pk_culture_culture_id" primary key
    (culture_id);
cluster production.culture using "pk_culture_culture_id";

alter table production.document add
    constraint "pk_document_document_node" primary key
    (document_node);
cluster production.document using "pk_document_document_node";

alter table person.email_address add
    constraint "pk_email_addr_b_entity_id_email_addr_id" primary key
    (business_entity_id, email_address_id);
cluster person.email_address using "pk_email_addr_b_entity_id_email_addr_id";

alter table human_resources.department add
    constraint "pk_dept_dept_id" primary key
    (department_id);
cluster human_resources.department using "pk_dept_dept_id";

alter table human_resources.employee add
    constraint "pk_employee_b_entity_id" primary key
    (business_entity_id);
cluster human_resources.employee using "pk_employee_b_entity_id";

alter table human_resources.employee_department_history add
    constraint "pk_employee_dept_history_b_entity_id_start_date_departm" primary key
    (business_entity_id, start_date, department_id, shift_id);
cluster human_resources.employee_department_history using "pk_employee_dept_history_b_entity_id_start_date_departm";

alter table human_resources.employee_pay_history add
    constraint "pk_employee_pay_history_b_entity_id_rate_change_date" primary key
    (business_entity_id, rate_change_date);
cluster human_resources.employee_pay_history using "pk_employee_pay_history_b_entity_id_rate_change_date";

alter table human_resources.job_candidate add
    constraint "pk_job_candidate_job_candidate_id" primary key
    (job_candidate_id);
cluster human_resources.job_candidate using "pk_job_candidate_job_candidate_id";

alter table production.illustration add
    constraint "pk_illustration_illustration_id" primary key
    (illustration_id);
cluster production.illustration using "pk_illustration_illustration_id";

alter table production.location add
    constraint "pk_location_location_id" primary key
    (location_id);
cluster production.location using "pk_location_location_id";

alter table person.password add
    constraint "pk_password_b_entity_id" primary key
    (business_entity_id);
cluster person.password using "pk_password_b_entity_id";

alter table person.person add
    constraint "pk_person_b_entity_id" primary key
    (business_entity_id);
cluster person.person using "pk_person_b_entity_id";

alter table person.person_phone add
    constraint "pk_person_phone_b_entity_id_phone_number_phone_number_type_id" primary key
    (business_entity_id, phone_number, phone_number_type_id);
cluster person.person_phone using "pk_person_phone_b_entity_id_phone_number_phone_number_type_id";

alter table person.phone_number_type add
    constraint "pk_phone_number_type_phone_number_type_id" primary key
    (phone_number_type_id);
cluster person.phone_number_type using "pk_phone_number_type_phone_number_type_id";

alter table production.product add
    constraint "pk_product_product_id" primary key
    (product_id);
cluster production.product using "pk_product_product_id";

alter table production.product_category add
    constraint "pk_product_category_product_category_id" primary key
    (product_category_id);
cluster production.product_category using "pk_product_category_product_category_id";

alter table production.product_cost_history add
    constraint "pk_product_cost_history_product_id_start_date" primary key
    (product_id, start_date);
cluster production.product_cost_history using "pk_product_cost_history_product_id_start_date";

alter table production.product_description add
    constraint "pk_product_description_product_description_id" primary key
    (product_description_id);
cluster production.product_description using "pk_product_description_product_description_id";

alter table production.product_document add
    constraint "pk_product_document_product_id_document_node" primary key
    (product_id, document_node);
cluster production.product_document using "pk_product_document_product_id_document_node";

alter table production.product_inventory add
    constraint "pk_product_inventory_product_id_location_id" primary key
    (product_id, location_id);
cluster production.product_inventory using "pk_product_inventory_product_id_location_id";

alter table production.product_list_price_history add
    constraint "pk_product_list_price_history_product_id_start_date" primary key
    (product_id, start_date);
cluster production.product_list_price_history using "pk_product_list_price_history_product_id_start_date";

alter table production.product_model add
    constraint "pk_product_model_product_model_id" primary key
    (product_model_id);
cluster production.product_model using "pk_product_model_product_model_id";

alter table production.product_model_illustration add
    constraint "pk_product_model_illust_product_model_id_illust_id" primary key
    (product_model_id, illustration_id);
cluster production.product_model_illustration using "pk_product_model_illust_product_model_id_illust_id";

alter table production.product_model_product_description_culture add
    constraint "pk_product_model_product_desc_culture_product_model_id_prod" primary key
    (product_model_id, product_description_id, culture_id);
cluster production.product_model_product_description_culture using "pk_product_model_product_desc_culture_product_model_id_prod";

alter table production.product_photo add
    constraint "pk_product_photo_product_photo_id" primary key
    (product_photo_id);
cluster production.product_photo using "pk_product_photo_product_photo_id";

alter table production.product_product_photo add
    constraint "pk_product_product_photo_product_id_product_photo_id" primary key
    (product_id, product_photo_id);

alter table production.product_review add
    constraint "pk_product_review_product_review_id" primary key
    (product_review_id);
cluster production.product_review using "pk_product_review_product_review_id";

alter table production.product_subcategory add
    constraint "pk_product_subcategory_product_subcategory_id" primary key
    (product_subcategory_id);
cluster production.product_subcategory using "pk_product_subcategory_product_subcategory_id";

alter table purchasing.product_vendor add
    constraint "pk_product_vendor_product_id_b_entity_id" primary key
    (product_id, business_entity_id);
cluster purchasing.product_vendor using "pk_product_vendor_product_id_b_entity_id";

alter table purchasing.purchase_order_detail add
    constraint "pk_purch_order_detail_purch_order_id_purch_order_detail_id" primary key
    (purchase_order_id, purchase_order_detail_id);
cluster purchasing.purchase_order_detail using "pk_purch_order_detail_purch_order_id_purch_order_detail_id";

alter table purchasing.purchase_order_header add
    constraint "pk_purchase_order_header_purchase_order_id" primary key
    (purchase_order_id);
cluster purchasing.purchase_order_header using "pk_purchase_order_header_purchase_order_id";

alter table sales.person_credit_card add
    constraint "pk_person_credit_card_b_entity_id_credit_card_id" primary key
    (business_entity_id, credit_card_id);
cluster sales.person_credit_card using "pk_person_credit_card_b_entity_id_credit_card_id";

alter table sales.sales_order_detail add
    constraint "pk_sales_order_detail_sales_order_id_sales_order_detail_id" primary key
    (sales_order_id, sales_order_detail_id);
cluster sales.sales_order_detail using "pk_sales_order_detail_sales_order_id_sales_order_detail_id";

alter table sales.sales_order_header add
    constraint "pk_sales_order_header_sales_order_id" primary key
    (sales_order_id);
cluster sales.sales_order_header using "pk_sales_order_header_sales_order_id";

alter table sales.sales_order_header_sales_reason add
    constraint "pk_sales_order_header_sale_reason_sale_order_id_sale_reason_id" primary key
    (sales_order_id, sales_reason_id);
cluster sales.sales_order_header_sales_reason using "pk_sales_order_header_sale_reason_sale_order_id_sale_reason_id";

alter table sales.sales_person add
    constraint "pk_sales_person_b_entity_id" primary key
    (business_entity_id);
cluster sales.sales_person using "pk_sales_person_b_entity_id";

alter table sales.sales_person_quota_history add
    constraint "pk_sales_person_quota_history_b_entity_id_quota_date" primary key
    (business_entity_id, quota_date); -- product_category_id);
cluster sales.sales_person_quota_history using "pk_sales_person_quota_history_b_entity_id_quota_date";

alter table sales.sales_reason add
    constraint "pk_sales_reason_sales_reason_id" primary key
    (sales_reason_id);
cluster sales.sales_reason using "pk_sales_reason_sales_reason_id";

alter table sales.sales_tax_rate add
    constraint "pk_sales_tax_rate_sales_tax_rate_id" primary key
    (sales_tax_rate_id);
cluster sales.sales_tax_rate using "pk_sales_tax_rate_sales_tax_rate_id";

alter table sales.sales_territory add
    constraint "pk_sales_territory_territory_id" primary key
    (territory_id);
cluster sales.sales_territory using "pk_sales_territory_territory_id";

alter table sales.sales_territory_history add
    constraint "pk_sales_territory_history_b_entity_id_start_date_territory_id" primary key
    (business_entity_id,  --sales person,
     start_date, territory_id);
cluster sales.sales_territory_history using "pk_sales_territory_history_b_entity_id_start_date_territory_id";

alter table production.scrap_reason add
    constraint "pk_scrap_reason_scrap_reason_id" primary key
    (scrap_reason_id);
cluster production.scrap_reason using "pk_scrap_reason_scrap_reason_id";

alter table human_resources.shift add
    constraint "pk_shift_shift_id" primary key
    (shift_id);
cluster human_resources.shift using "pk_shift_shift_id";

alter table purchasing.ship_method add
    constraint "pk_ship_method_ship_method_id" primary key
    (ship_method_id);
cluster purchasing.ship_method using "pk_ship_method_ship_method_id";

alter table sales.shopping_cart_item add
    constraint "pk_shopping_cart_item_shopping_cart_item_id" primary key
    (shopping_cart_item_id);
cluster sales.shopping_cart_item using "pk_shopping_cart_item_shopping_cart_item_id";

alter table sales.special_offer add
    constraint "pk_special_offer_special_offer_id" primary key
    (special_offer_id);
cluster sales.special_offer using "pk_special_offer_special_offer_id";

alter table sales.special_offer_product add
    constraint "pk_special_offer_product_special_offer_id_product_id" primary key
    (special_offer_id, product_id);
cluster sales.special_offer_product using "pk_special_offer_product_special_offer_id_product_id";

alter table person.state_province add
    constraint "pk_state_province_state_province_id" primary key
    (state_province_id);
cluster person.state_province using "pk_state_province_state_province_id";

alter table sales.store add
    constraint "pk_store_b_entity_id" primary key
    (business_entity_id);
cluster sales.store using "pk_store_b_entity_id";

alter table production.transaction_history add
    constraint "pk_transaction_history_transaction_id" primary key
    (transaction_id);
cluster production.transaction_history using "pk_transaction_history_transaction_id";

alter table production.transaction_history_archive add
    constraint "pk_transaction_history_archive_transaction_id" primary key
    (transaction_id);
cluster production.transaction_history_archive using "pk_transaction_history_archive_transaction_id";

alter table production.unit_measure add
    constraint "pk_unit_measure_unit_measure_code" primary key
    (unit_measure_code);
cluster production.unit_measure using "pk_unit_measure_unit_measure_code";

alter table purchasing.vendor add
    constraint "pk_vendor_b_entity_id" primary key
    (business_entity_id);
cluster purchasing.vendor using "pk_vendor_b_entity_id";

alter table production.work_order add
    constraint "pk_work_order_work_order_id" primary key
    (work_order_id);
cluster production.work_order using "pk_work_order_work_order_id";

alter table production.work_order_routing add
    constraint "pk_work_order_routing_work_order_id_product_id_operation_seq" primary key
    (work_order_id, product_id, operation_sequence);
cluster production.work_order_routing using "pk_work_order_routing_work_order_id_product_id_operation_seq";



-------------------------------------
-- FOREIGN KEYS
-------------------------------------

alter table person.address add
    constraint "fk_addr_state_province_state_province_id" foreign key
    (state_province_id) references person.state_province(state_province_id);

alter table production.bill_of_materials add
    constraint "fk_bill_of_materials_product_product_assembly_id" foreign key
    (product_assembly_id) references production.product(product_id);
alter table production.bill_of_materials add
    constraint "fk_bill_of_materials_product_component_id" foreign key
    (component_id) references production.product(product_id);
alter table production.bill_of_materials add
    constraint "fk_bill_of_materials_unit_measure_unit_measure_code" foreign key
    (unit_measure_code) references production.unit_measure(unit_measure_code);

alter table person.business_entity_address add
    constraint "fk_b_entity_addr_addr_addr_id" foreign key
    (address_id) references person.address(address_id);
alter table person.business_entity_address add
    constraint "fk_b_entity_addr_addr_type_addr_type_id" foreign key
    (address_type_id) references person.address_type(address_type_id);
alter table person.business_entity_address add
    constraint "fk_b_entity_addr_b_entity_b_entity_id" foreign key
    (business_entity_id) references person.business_entity(business_entity_id);

alter table person.business_entity_contact add
    constraint "fk_b_entity_contact_person_person_id" foreign key
    (person_id) references person.person(business_entity_id);
alter table person.business_entity_contact add
    constraint "fk_b_entity_contact_contact_type_contact_type_id" foreign key
    (contact_type_id) references person.contact_type(contact_type_id);
alter table person.business_entity_contact add
    constraint "fk_b_entity_contact_b_entity_b_entity_id" foreign key
    (business_entity_id) references person.business_entity(business_entity_id);

alter table sales.country_region_currency add
    constraint "fk_country_region_currency_country_region_country_region_code" foreign key
    (country_region_code) references person.country_region(country_region_code);
alter table sales.country_region_currency add
    constraint "fk_country_region_currency_currency_currency_code" foreign key
    (currency_code) references sales.currency(currency_code);

alter table sales.currency_rate add
    constraint "fk_currency_rate_currency_from_currency_code" foreign key
    (from_currency_code) references sales.currency(currency_code);
alter table sales.currency_rate add
    constraint "fk_currency_rate_currency_to_currency_code" foreign key
    (to_currency_code) references sales.currency(currency_code);

alter table sales.customer add
    constraint "fk_customer_person_person_id" foreign key
    (person_id) references person.person(business_entity_id);
alter table sales.customer add
    constraint "fk_customer_store_store_id" foreign key
    (store_id) references sales.store(business_entity_id);
alter table sales.customer add
    constraint "fk_customer_sales_territory_territory_id" foreign key
    (territory_id) references sales.sales_territory(territory_id);

alter table production.document add
    constraint "fk_document_employee_owner" foreign key
    (owner) references human_resources.employee(business_entity_id);

alter table person.email_address add
    constraint "fk_email_addr_person_b_entity_id" foreign key
    (business_entity_id) references person.person(business_entity_id);

alter table human_resources.employee add
    constraint "fk_employee_person_b_entity_id" foreign key
    (business_entity_id) references person.person(business_entity_id);

alter table human_resources.employee_department_history add
    constraint "fk_employee_dept_history_dept_dept_id" foreign key
    (department_id) references human_resources.department(department_id);
alter table human_resources.employee_department_history add
    constraint "fk_employee_dept_history_employee_b_entity_id" foreign key
    (business_entity_id) references human_resources.employee(business_entity_id);
alter table human_resources.employee_department_history add
    constraint "fk_employee_dept_history_shift_shift_id" foreign key
    (shift_id) references human_resources.shift(shift_id);

alter table human_resources.employee_pay_history add
    constraint "fk_employee_pay_history_employee_b_entity_id" foreign key
    (business_entity_id) references human_resources.employee(business_entity_id);

alter table human_resources.job_candidate add
    constraint "fk_job_candidate_employee_b_entity_id" foreign key
    (business_entity_id) references human_resources.employee(business_entity_id);

alter table person.password add
    constraint "fk_password_person_b_entity_id" foreign key
    (business_entity_id) references person.person(business_entity_id);

alter table person.person add
    constraint "fk_person_b_entity_b_entity_id" foreign key
    (business_entity_id) references person.business_entity(business_entity_id);

alter table sales.person_credit_card add
    constraint "fk_person_credit_card_person_b_entity_id" foreign key
    (business_entity_id) references person.person(business_entity_id);
alter table sales.person_credit_card add
    constraint "fk_person_credit_card_credit_card_credit_card_id" foreign key
    (credit_card_id) references sales.credit_card(credit_card_id);

alter table person.person_phone add
    constraint "fk_person_phone_person_b_entity_id" foreign key
    (business_entity_id) references person.person(business_entity_id);
alter table person.person_phone add
    constraint "fk_person_phone_phone_number_type_phone_number_type_id" foreign key
    (phone_number_type_id) references person.phone_number_type(phone_number_type_id);

alter table production.product add
    constraint "fk_product_unit_measure_size_unit_measure_code" foreign key
    (size_unit_measure_code) references production.unit_measure(unit_measure_code);
alter table production.product add
    constraint "fk_product_unit_measure_weight_unit_measure_code" foreign key
    (weight_unit_measure_code) references production.unit_measure(unit_measure_code);
alter table production.product add
    constraint "fk_product_product_model_product_model_id" foreign key
    (product_model_id) references production.product_model(product_model_id);
alter table production.product add
    constraint "fk_product_product_subcategory_product_subcategory_id" foreign key
    (product_subcategory_id) references production.product_subcategory(product_subcategory_id);

alter table production.product_cost_history add
    constraint "fk_product_cost_history_product_product_id" foreign key
    (product_id) references production.product(product_id);

alter table production.product_document add
    constraint "fk_product_document_product_product_id" foreign key
    (product_id) references production.product(product_id);
alter table production.product_document add
    constraint "fk_product_document_document_document_node" foreign key
    (document_node) references production.document(document_node);

alter table production.product_inventory add
    constraint "fk_product_inventory_location_location_id" foreign key
    (location_id) references production.location(location_id);
alter table production.product_inventory add
    constraint "fk_product_inventory_product_product_id" foreign key
    (product_id) references production.product(product_id);

alter table production.product_list_price_history add
    constraint "fk_product_list_price_history_product_product_id" foreign key
    (product_id) references production.product(product_id);

alter table production.product_model_illustration add
    constraint "fk_product_model_illustration_product_model_product_model_id" foreign key
    (product_model_id) references production.product_model(product_model_id);
alter table production.product_model_illustration add
    constraint "fk_product_model_illustration_illustration_illustration_id" foreign key
    (illustration_id) references production.illustration(illustration_id);

alter table production.product_model_product_description_culture add
    constraint "fk_product_model_product_desc_culture_product_desc_pro" foreign key
    (product_description_id) references production.product_description(product_description_id);
alter table production.product_model_product_description_culture add
    constraint "fk_product_model_product_desc_culture_culture_id" foreign key
    (culture_id) references production.culture(culture_id);
alter table production.product_model_product_description_culture add
    constraint "fk_product_model_product_desc_culture_product_model_id" foreign key
    (product_model_id) references production.product_model(product_model_id);

alter table production.product_product_photo add
    constraint "fk_product_product_photo_product_product_id" foreign key
    (product_id) references production.product(product_id);
alter table production.product_product_photo add
    constraint "fk_product_product_photo_product_photo_product_photo_id" foreign key
    (product_photo_id) references production.product_photo(product_photo_id);

alter table production.product_review add
    constraint "fk_product_review_product_product_id" foreign key
    (product_id) references production.product(product_id);

alter table production.product_subcategory add
    constraint "fk_product_subcategory_product_category_product_category_id" foreign key
    (product_category_id) references production.product_category(product_category_id);

alter table purchasing.product_vendor add
    constraint "fk_product_vendor_product_product_id" foreign key
    (product_id) references production.product(product_id);
alter table purchasing.product_vendor add
    constraint "fk_product_vendor_unit_measure_unit_measure_code" foreign key
    (unit_measure_code) references production.unit_measure(unit_measure_code);
alter table purchasing.product_vendor add
    constraint "fk_product_vendor_vendor_b_entity_id" foreign key
    (business_entity_id) references purchasing.vendor(business_entity_id);

alter table purchasing.purchase_order_detail add
    constraint "fk_purchase_order_detail_product_product_id" foreign key
    (product_id) references production.product(product_id);
alter table purchasing.purchase_order_detail add
    constraint "fk_purchase_order_detail_purchase_order_header_purch_order_id" foreign key
    (purchase_order_id) references purchasing.purchase_order_header(purchase_order_id);

alter table purchasing.purchase_order_header add
    constraint "fk_purchase_order_header_employee_employee_id" foreign key
    (employee_id) references human_resources.employee(business_entity_id);
alter table purchasing.purchase_order_header add
    constraint "fk_purchase_order_header_vendor_vendor_id" foreign key
    (vendor_id) references purchasing.vendor(business_entity_id);
alter table purchasing.purchase_order_header add
    constraint "fk_purchase_order_header_ship_method_ship_method_id" foreign key
    (ship_method_id) references purchasing.ship_method(ship_method_id);

alter table sales.sales_order_detail add
    constraint "fk_sales_order_detail_sales_order_header_sales_order_id" foreign key
    (sales_order_id) references sales.sales_order_header(sales_order_id) on delete cascade;
alter table sales.sales_order_detail add
    constraint "fk_sales_order_detail_special_offer_pr_special_offer_id_pr_id" foreign key
    (special_offer_id, product_id) references sales.special_offer_product(special_offer_id, product_id);

alter table sales.sales_order_header add
    constraint "fk_sales_order_header_addr_bill_to_addr_id" foreign key
    (bill_to_address_id) references person.address(address_id);
alter table sales.sales_order_header add
    constraint "fk_sales_order_header_addr_ship_to_addr_id" foreign key
    (ship_to_address_id) references person.address(address_id);
alter table sales.sales_order_header add
    constraint "fk_sales_order_header_credit_card_credit_card_id" foreign key
    (credit_card_id) references sales.credit_card(credit_card_id);
alter table sales.sales_order_header add
    constraint "fk_sales_order_header_currency_rate_currency_rate_id" foreign key
    (currency_rate_id) references sales.currency_rate(currency_rate_id);
alter table sales.sales_order_header add
    constraint "fk_sales_order_header_customer_customer_id" foreign key
    (customer_id) references sales.customer(customer_id);
alter table sales.sales_order_header add
    constraint "fk_sales_order_header_sales_person_sales_person_id" foreign key
    (sales_person_id) references sales.sales_person(business_entity_id);
alter table sales.sales_order_header add
    constraint "fk_sales_order_header_ship_method_ship_method_id" foreign key
    (ship_method_id) references purchasing.ship_method(ship_method_id);
alter table sales.sales_order_header add
    constraint "fk_sales_order_header_sales_territory_territory_id" foreign key
    (territory_id) references sales.sales_territory(territory_id);

alter table sales.sales_order_header_sales_reason add
    constraint "fk_sales_order_header_sales_reason_sales_reason_id" foreign key
    (sales_reason_id) references sales.sales_reason(sales_reason_id);
alter table sales.sales_order_header_sales_reason add
    constraint "fk_sales_order_header_sales_reason_sales_order_id" foreign key
    (sales_order_id) references sales.sales_order_header(sales_order_id) on delete cascade;

alter table sales.sales_person add
    constraint "fk_sales_person_employee_b_entity_id" foreign key
    (business_entity_id) references human_resources.employee(business_entity_id);
alter table sales.sales_person add
    constraint "fk_sales_person_sales_territory_territory_id" foreign key
    (territory_id) references sales.sales_territory(territory_id);

alter table sales.sales_person_quota_history add
    constraint "fk_sales_person_quota_history_sales_person_b_entity_id" foreign key
    (business_entity_id) references sales.sales_person(business_entity_id);

alter table sales.sales_tax_rate add
    constraint "fk_sales_tax_rate_state_province_state_province_id" foreign key
    (state_province_id) references person.state_province(state_province_id);

alter table sales.sales_territory add
    constraint "fk_sales_territory_country_region_country_region_code" foreign key
    (country_region_code) references person.country_region(country_region_code);

alter table sales.sales_territory_history add
    constraint "fk_sales_territory_history_sales_person_b_entity_id" foreign key
    (business_entity_id) references sales.sales_person(business_entity_id);
alter table sales.sales_territory_history add
    constraint "fk_sales_territory_history_sales_territory_territory_id" foreign key
    (territory_id) references sales.sales_territory(territory_id);

alter table sales.shopping_cart_item add
    constraint "fk_shopping_cart_item_product_product_id" foreign key
    (product_id) references production.product(product_id);

alter table sales.special_offer_product add
    constraint "fk_special_offer_product_product_product_id" foreign key
    (product_id) references production.product(product_id);
alter table sales.special_offer_product add
    constraint "fk_special_offer_product_special_offer_special_offer_id" foreign key
    (special_offer_id) references sales.special_offer(special_offer_id);

alter table person.state_province add
    constraint "fk_state_province_country_region_country_region_code" foreign key
    (country_region_code) references person.country_region(country_region_code);
alter table person.state_province add
    constraint "fk_state_province_sales_territory_territory_id" foreign key
    (territory_id) references sales.sales_territory(territory_id);

alter table sales.store add
    constraint "fk_store_b_entity_b_entity_id" foreign key
    (business_entity_id) references person.business_entity(business_entity_id);
alter table sales.store add
    constraint "fk_store_sales_person_sales_person_id" foreign key
    (sales_person_id) references sales.sales_person(business_entity_id);

alter table production.transaction_history add
    constraint "fk_transaction_history_product_product_id" foreign key
    (product_id) references production.product(product_id);

alter table purchasing.vendor add
    constraint "fk_vendor_b_entity_b_entity_id" foreign key
    (business_entity_id) references person.business_entity(business_entity_id);

alter table production.work_order add
    constraint "fk_work_order_product_product_id" foreign key
    (product_id) references production.product(product_id);
alter table production.work_order add
    constraint "fk_work_order_scrap_reason_scrap_reason_id" foreign key
    (scrap_reason_id) references production.scrap_reason(scrap_reason_id);

alter table production.work_order_routing add
    constraint "fk_work_order_routing_location_location_id" foreign key
    (location_id) references production.location(location_id);
alter table production.work_order_routing add
    constraint "fk_work_order_routing_work_order_work_order_id" foreign key
    (work_order_id) references production.work_order(work_order_id);



-------------------------------------
-- VIEWS
-------------------------------------

-- Fun to see the difference in XML-oriented queries between MSSQLServer and Postgres.
-- First here's an original MSSQL query:

-- CREATE VIEW [Person].[vAdditionalContactInfo]
-- AS
-- SELECT
--     [BusinessEntityID]
--     ,[FirstName]
--     ,[MiddleName]
--     ,[LastName]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:telephoneNumber)[1]/act:number', 'nvarchar(50)') AS [TelephoneNumber]
--     ,LTRIM(RTRIM([ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:telephoneNumber/act:SpecialInstructions/text())[1]', 'nvarchar(max)'))) AS [TelephoneSpecialInstructions]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:Street)[1]', 'nvarchar(50)') AS [Street]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:City)[1]', 'nvarchar(50)') AS [City]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:StateProvince)[1]', 'nvarchar(50)') AS [StateProvince]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:PostalCode)[1]', 'nvarchar(50)') AS [PostalCode]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:CountryRegion)[1]', 'nvarchar(50)') AS [CountryRegion]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:SpecialInstructions/text())[1]', 'nvarchar(max)') AS [HomeAddressSpecialInstructions]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:eMailAddress)[1]', 'nvarchar(128)') AS [EMailAddress]
--     ,LTRIM(RTRIM([ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:SpecialInstructions/text())[1]', 'nvarchar(max)'))) AS [EMailSpecialInstructions]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:SpecialInstructions/act:telephoneNumber/act:number)[1]', 'nvarchar(50)') AS [EMailTelephoneNumber]
--     ,[rowguid]
--     ,[ModifiedDate]
-- FROM [Person].[Person]
-- OUTER APPLY [AdditionalContactInfo].nodes(
--     'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--     /ci:AdditionalContactInfo') AS ContactInfo(ref)
-- WHERE [AdditionalContactInfo] IS NOT NULL;


-- And now the Postgres version, which is a little more trim:

create view person.v_additional_contact_info
as
select
    p.business_entity_id
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,(xpath('(act:telephoneNumber)[1]/act:number/text()',                node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS telephone_number
    ,BTRIM(
     (xpath('(act:telephoneNumber)[1]/act:SpecialInstructions/text()',   node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]::VARCHAR)
               AS telephone_special_instructions
    ,(xpath('(act:homePostalAddress)[1]/act:Street/text()',              node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS street
    ,(xpath('(act:homePostalAddress)[1]/act:City/text()',                node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS city
    ,(xpath('(act:homePostalAddress)[1]/act:StateProvince/text()',       node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS state_province
    ,(xpath('(act:homePostalAddress)[1]/act:PostalCode/text()',          node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS postal_code
    ,(xpath('(act:homePostalAddress)[1]/act:CountryRegion/text()',       node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS country_region
    ,(xpath('(act:homePostalAddress)[1]/act:SpecialInstructions/text()', node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS home_address_special_instructions
    ,(xpath('(act:eMail)[1]/act:eMailAddress/text()',                    node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS e_mail_address
    ,BTRIM(
     (xpath('(act:eMail)[1]/act:SpecialInstructions/text()',             node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]::VARCHAR)
               AS e_mail_special_instructions
    ,(xpath('((act:eMail)[1]/act:SpecialInstructions/act:telephoneNumber)[1]/act:number/text()', node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS e_mail_telephone_number
    ,p.rowguid
    ,p.modified_date
from person.person as p
  left outer join
    (select
      business_entity_id
      ,unnest(xpath('/ci:AdditionalContactInfo',
        additional_contact_info,
        '{{ci,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo}}')) as node
    from person.person
    where additional_contact_info is not null) as additional
  on p.business_entity_id = additional.business_entity_id;


create view human_resources.v_employee
as
select
    e.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,e.job_title 
    ,pp.phone_number
    ,pnt.name as phone_number_type
    ,ea.email_address
    ,p.email_promotion
    ,a.address_line1
    ,a.address_line2
    ,a.city
    ,sp.name as state_province_name
    ,a.postal_code
    ,cr.name as country_region_name
    ,p.additional_contact_info
from human_resources.employee e
  inner join person.person p
    on p.business_entity_id = e.business_entity_id
  inner join person.business_entity_address bea
    on bea.business_entity_id = e.business_entity_id
  inner join person.address a
    on a.address_id = bea.address_id
  inner join person.state_province sp
    on sp.state_province_id = a.state_province_id
  inner join person.country_region cr
    on cr.country_region_code = sp.country_region_code
  left outer join person.person_phone pp
    on pp.business_entity_id = p.business_entity_id
  left outer join person.phone_number_type pnt
    on pp.phone_number_type_id = pnt.phone_number_type_id
  left outer join person.email_address ea
    on p.business_entity_id = ea.business_entity_id;


create view human_resources.v_employee_department
as
select
    e.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,e.job_title
    ,d.name as department
    ,d.group_name
    ,edh.start_date
from human_resources.employee e
  inner join person.person p
    on p.business_entity_id = e.business_entity_id
  inner join human_resources.employee_department_history edh
    on e.business_entity_id = edh.business_entity_id
  inner join human_resources.department d
    on edh.department_id = d.department_id
where edh.end_date is null;


create view human_resources.v_employee_department_history
as
select
    e.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,s.name as shift
    ,d.name as department
    ,d.group_name
    ,edh.start_date
    ,edh.end_date
from human_resources.employee e
  inner join person.person p
    on p.business_entity_id = e.business_entity_id
  inner join human_resources.employee_department_history edh
    on e.business_entity_id = edh.business_entity_id
  inner join human_resources.department d
    on edh.department_id = d.department_id
  inner join human_resources.shift s
    on s.shift_id = edh.shift_id;


create view sales.v_individual_customer
as
select
    p.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,pp.phone_number
    ,pnt.name as phone_number_type
    ,ea.email_address
    ,p.email_promotion
    ,at.name as address_type
    ,a.address_line1
    ,a.address_line2
    ,a.city
    ,sp.name as state_province_name
    ,a.postal_code
    ,cr.name as country_region_name
    ,p.demographics
from person.person p
  inner join person.business_entity_address bea
    on bea.business_entity_id = p.business_entity_id
  inner join person.address a
    on a.address_id = bea.address_id
  inner join person.state_province sp
    on sp.state_province_id = a.state_province_id
  inner join person.country_region cr
    on cr.country_region_code = sp.country_region_code
  inner join person.address_type at
    on at.address_type_id = bea.address_type_id
  inner join sales.customer c
    on c.person_id = p.business_entity_id
  left outer join person.email_address ea
    on ea.business_entity_id = p.business_entity_id
  left outer join person.person_phone pp
    on pp.business_entity_id = p.business_entity_id
  left outer join person.phone_number_type pnt
    on pnt.phone_number_type_id = pp.phone_number_type_id
where c.store_id is null;


create view sales.v_person_demographics
as
select
    business_entity_id
    ,CAST((xpath('n:TotalPurchaseYTD/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS money)
            AS total_purchase_ytd
    ,CAST((xpath('n:DateFirstPurchase/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS DATE)
            AS date_first_purchase
    ,CAST((xpath('n:BirthDate/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS DATE)
            AS birth_date
    ,(xpath('n:MaritalStatus/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(1)
            AS marital_status
    ,(xpath('n:YearlyIncome/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS yearly_income
    ,(xpath('n:Gender/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(1)
            AS gender
    ,CAST((xpath('n:TotalChildren/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS total_children
    ,CAST((xpath('n:NumberChildrenAtHome/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS number_children_at_home
    ,(xpath('n:Education/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS education
    ,(xpath('n:Occupation/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS occupation
    ,CAST((xpath('n:HomeOwnerFlag/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS BOOLEAN)
            AS home_owner_flag
    ,CAST((xpath('n:NumberCarsOwned/text()', demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS number_cars_owned
from person.person
  where demographics is not null;


create view human_resources.v_job_candidate
as
select
    job_candidate_id
    ,business_entity_id
    ,(xpath('/n:Resume/n:Name/n:Name.Prefix/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "name.prefix"
    ,(xpath('/n:Resume/n:Name/n:Name.First/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "name.first"
    ,(xpath('/n:Resume/n:Name/n:Name.Middle/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "name.middle"
    ,(xpath('/n:Resume/n:Name/n:Name.Last/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "name.last"
    ,(xpath('/n:Resume/n:Name/n:Name.Suffix/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "name.suffix"
    ,(xpath('/n:Resume/n:Skills/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "skills"
    ,(xpath('n:Address/n:Addr.Type/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "addr.type"
    ,(xpath('n:Address/n:Addr.Location/n:Location/n:Loc.CountryRegion/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "addr.loc.country_region"
    ,(xpath('n:Address/n:Addr.Location/n:Location/n:Loc.State/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "addr.loc.state"
    ,(xpath('n:Address/n:Addr.Location/n:Location/n:Loc.City/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "addr.loc.city"
    ,(xpath('n:Address/n:Addr.PostalCode/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(20)
                   AS "addr.postal_code"
    ,(xpath('/n:Resume/n:EMail/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "e_mail"
    ,(xpath('/n:Resume/n:WebSite/text()', resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "web_site"
    ,modified_date
from human_resources.job_candidate;


-- In this case we UNNEST in order to have multiple previous employments listed for
-- each job candidate.  But things become very brittle when using UNNEST like this,
-- with multiple columns...
-- ... if any of our Employment fragments were missing something, such as randomly a
-- Emp.FunctionCategory is not there, then there will be 0 rows returned.  Each
-- Employment element must contain all 10 sub-elements for this approach to work.
-- (See the Education example below for a better alternate approach!)
create view human_resources.v_job_candidate_employment
as
select
    job_candidate_id
    ,CAST(UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.StartDate/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::VARCHAR(20) AS DATE)
                                                AS "emp.start_date"
    ,CAST(UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.EndDate/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::VARCHAR(20) AS DATE)
                                                AS "emp.end_date"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.OrgName/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar(100)
                                                AS "emp.org_name"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.JobTitle/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar(100)
                                                AS "emp.job_title"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Responsibility/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "emp.responsibility"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.FunctionCategory/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "emp.function_category"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.IndustryCategory/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "emp.industry_category"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Location/ns:Location/ns:Loc.CountryRegion/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "emp.loc.country_region"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Location/ns:Location/ns:Loc.State/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "emp.loc.state"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Location/ns:Location/ns:Loc.City/text()', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "emp.loc.city"
  from human_resources.job_candidate;


-- In this data set, not every listed education has a minor.  (OK, actually NONE of them do!)
-- So instead of using multiple UNNEST as above, which would result in 0 rows returned,
-- we just UNNEST once in a derived table, then convert each XML fragment into a document again
-- with one <root> element and a shorter namespace for ns:, and finally just use xpath on
-- all the created documents.
create view human_resources.v_job_candidate_education
as
select
  jc.job_candidate_id
  ,(xpath('/root/ns:Education/ns:Edu.Level/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(50)
                             AS "edu.level"
  ,CAST((xpath('/root/ns:Education/ns:Edu.StartDate/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::VARCHAR(20) AS DATE)
                             AS "edu.start_date"
  ,CAST((xpath('/root/ns:Education/ns:Edu.EndDate/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::VARCHAR(20) AS DATE)
                             AS "edu.end_date"
  ,(xpath('/root/ns:Education/ns:Edu.Degree/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(50)
                             AS "edu.degree"
  ,(xpath('/root/ns:Education/ns:Edu.Major/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(50)
                             AS "edu.major"
  ,(xpath('/root/ns:Education/ns:Edu.Minor/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(50)
                             AS "edu.minor"
  ,(xpath('/root/ns:Education/ns:Edu.GPA/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(5)
                             AS "edu.gpa"
  ,(xpath('/root/ns:Education/ns:Edu.GPAScale/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(5)
                             AS "edu.gpa_scale"
  ,(xpath('/root/ns:Education/ns:Edu.School/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(100)
                             AS "edu.school"
  ,(xpath('/root/ns:Education/ns:Edu.Location/ns:Location/ns:Loc.CountryRegion/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(100)
                             AS "edu.loc.country_region"
  ,(xpath('/root/ns:Education/ns:Edu.Location/ns:Location/ns:Loc.State/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(100)
                             AS "edu.loc.state"
  ,(xpath('/root/ns:Education/ns:Edu.Location/ns:Location/ns:Loc.City/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(100)
                             AS "edu.loc.city"
from (select job_candidate_id
    -- because the underlying xml data used in this example has namespaces defined at the document level,
    -- when we take individual fragments using unnest then each fragment has no idea of the namespaces.
    -- so here each fragment gets turned back into its own document with a root element that defines a
    -- simpler thing for "ns" since this will only be used only in the xpath queries above.
    ,('<root xmlns:ns="http://adventureworks.com">' ||
      unnesting.education::varchar ||
      '</root>')::xml as doc
  from (select job_candidate_id
      ,UNNEST(xpath('/ns:Resume/ns:Education', resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}')) AS Education
    from human_resources.job_candidate) as unnesting) as jc;


-- Products and product descriptions by language.
-- We're making this a materialized view so that performance can be better.
create materialized view production.v_product_and_description
as
select
    p.product_id
    ,p.name
    ,pm.name as product_model
    ,pmx.culture_id
    ,pd.description
from production.product p
    inner join production.product_model pm
    on p.product_model_id = pm.product_model_id
    inner join production.product_model_product_description_culture pmx
    on pm.product_model_id = pmx.product_model_id
    inner join production.product_description pd
    on pmx.product_description_id = pd.product_description_id;

-- Index the vProductAndDescription view
create unique index ix_v_product_and_description on production.v_product_and_description(culture_id, product_id);
cluster production.v_product_and_description using ix_v_product_and_description;
-- Note that with a materialized view, changes to the underlying tables will
-- not change the contents of the view.  In order to maintain the index, if there
-- are changes to any of the 4 tables then you would need to run:
--   REFRESH MATERIALIZED VIEW Production.vProductAndDescription;


create view production.v_product_model_catalog_description
as
select
  product_model_id
  ,name
  ,(xpath('/p1:ProductDescription/p1:Summary/html:p/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{html,http://www.w3.org/1999/xhtml}}'))[1]::varchar
                                 AS "summary"
  ,(xpath('/p1:ProductDescription/p1:Manufacturer/p1:Name/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar
                                  AS manufacturer
  ,(xpath('/p1:ProductDescription/p1:Manufacturer/p1:Copyright/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(30)
                                                  AS copyright
  ,(xpath('/p1:ProductDescription/p1:Manufacturer/p1:ProductURL/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                  AS product_url
  ,(xpath('/p1:ProductDescription/p1:Features/wm:Warranty/wm:WarrantyPeriod/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                          AS warranty_period
  ,(xpath('/p1:ProductDescription/p1:Features/wm:Warranty/wm:Description/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                          AS warranty_description
  ,(xpath('/p1:ProductDescription/p1:Features/wm:Maintenance/wm:NoOfYears/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                             AS no_of_years
  ,(xpath('/p1:ProductDescription/p1:Features/wm:Maintenance/wm:Description/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                             AS maintenance_description
  ,(xpath('/p1:ProductDescription/p1:Features/wf:wheel/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS wheel
  ,(xpath('/p1:ProductDescription/p1:Features/wf:saddle/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS saddle
  ,(xpath('/p1:ProductDescription/p1:Features/wf:pedal/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS pedal
  ,(xpath('/p1:ProductDescription/p1:Features/wf:BikeFrame/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar
                                              AS bike_frame
  ,(xpath('/p1:ProductDescription/p1:Features/wf:crankset/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS crankset
  ,(xpath('/p1:ProductDescription/p1:Picture/p1:Angle/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS picture_angle
  ,(xpath('/p1:ProductDescription/p1:Picture/p1:Size/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS picture_size
  ,(xpath('/p1:ProductDescription/p1:Picture/p1:ProductPhotoID/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS product_photo_id
  ,(xpath('/p1:ProductDescription/p1:Specifications/Material/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS material
  ,(xpath('/p1:ProductDescription/p1:Specifications/Color/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS color
  ,(xpath('/p1:ProductDescription/p1:Specifications/ProductLine/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS product_line
  ,(xpath('/p1:ProductDescription/p1:Specifications/Style/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS style
  ,(xpath('/p1:ProductDescription/p1:Specifications/RiderExperience/text()', catalog_description, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(1024)
                                                 AS rider_experience
  ,rowguid
  ,modified_date
from production.product_model
where catalog_description is not null;


-- Instructions have many locations, and locations have many steps
create view production.v_product_model_instructions
as
select
    pm.product_model_id
    ,pm.name
    -- access the overall instructions xml brought through from %line 2938 and %line 2943
    ,(xpath('/ns:root/text()', pm.instructions, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelManuInstructions}}'))[1]::varchar as instructions
    -- bring out information about the location, broken out in %line 2945
    ,cast((xpath('@LocationID', pm.mfg_instructions))[1]::varchar as integer) as "location_id"
    ,cast((xpath('@SetupHours', pm.mfg_instructions))[1]::varchar as decimal(9, 4)) as "setup_hours"
    ,cast((xpath('@MachineHours', pm.mfg_instructions))[1]::varchar as decimal(9, 4)) as "machine_hours"
    ,cast((xpath('@LaborHours', pm.mfg_instructions))[1]::varchar as decimal(9, 4)) as "labor_hours"
    ,cast((xpath('@LotSize', pm.mfg_instructions))[1]::varchar as integer) as "lot_size"
    -- show specific detail about each step broken out in %line 2940
    ,(xpath('/step/text()', pm.step))[1]::varchar(1024) as "step"
    ,pm.rowguid
    ,pm.modified_date
from (select locations.product_model_id, locations.name, locations.rowguid, locations.modified_date
    ,locations.instructions, locations.mfg_instructions
    -- further break out the location information from the inner query below into individual steps
    ,unnest(xpath('step', locations.mfg_instructions)) as step
  from (select
      -- just pass these through so they can be referenced at the outermost query
      product_model_id, name, rowguid, modified_date, instructions
      -- and also break out instructions into individual locations to pass up to the middle query
      ,unnest(xpath('/ns:root/ns:Location', instructions, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelManuInstructions}}')) as mfg_instructions
    from production.product_model) as locations) as pm;


create view sales.v_sales_person
as
select
    s.business_entity_id
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,e.job_title
    ,pp.phone_number
    ,pnt.name as phone_number_type
    ,ea.email_address
    ,p.email_promotion
    ,a.address_line1
    ,a.address_line2
    ,a.city
    ,sp.name as state_province_name
    ,a.postal_code
    ,cr.name as country_region_name
    ,st.name as territory_name
    ,st.group as territory_group
    ,s.sales_quota
    ,s.sales_ytd
    ,s.sales_last_year
from sales.sales_person s
  inner join human_resources.employee e
    on e.business_entity_id = s.business_entity_id
  inner join person.person p
    on p.business_entity_id = s.business_entity_id
  inner join person.business_entity_address bea
    on bea.business_entity_id = s.business_entity_id
  inner join person.address a
    on a.address_id = bea.address_id
  inner join person.state_province sp
    on sp.state_province_id = a.state_province_id
  inner join person.country_region cr
    on cr.country_region_code = sp.country_region_code
  left outer join sales.sales_territory st
    on st.territory_id = s.territory_id
  left outer join person.email_address ea
    on ea.business_entity_id = p.business_entity_id
  left outer join person.person_phone pp
    on pp.business_entity_id = p.business_entity_id
  left outer join person.phone_number_type pnt
    on pnt.phone_number_type_id = pp.phone_number_type_id;


-- This view provides the aggregated data that gets used in the PIVOTed view below
create view sales.v_sales_person_sales_by_fiscal_years_data
as
-- Of the 56 possible combinations of one of the 14 SalesPersons selling across one of
-- 4 FiscalYears, here we end up with 48 rows of aggregated data (since some sales people
-- were hired and started working in FY2012 or FY2013).
select granular.sales_person_id, granular.full_name, granular.job_title, granular.sales_territory, sum(granular.sub_total) as sales_total, granular.fiscal_year
from
-- Brings back 3703 rows of data -- there are 3806 total sales done by a SalesPerson,
-- of which 103 do not have any sales territory.  This is fed into the outer GROUP BY
-- which results in 48 aggregated rows of sales data.
  (select
      soh.sales_person_id
      ,p.first_name || ' ' || coalesce(p.middle_name || ' ', '') || p.last_name as full_name
      ,e.job_title
      ,st.name as sales_territory
      ,soh.sub_total
      ,extract(year from soh.order_date + '6 months'::interval) as fiscal_year
  from sales.sales_person sp
    inner join sales.sales_order_header soh
      on sp.business_entity_id = soh.sales_person_id
    inner join sales.sales_territory st
      on sp.territory_id = st.territory_id
    inner join human_resources.employee e
      on soh.sales_person_id = e.business_entity_id
    inner join person.person p
      on p.business_entity_id = sp.business_entity_id
  ) as granular
group by granular.sales_person_id, granular.full_name, granular.job_title, granular.sales_territory, granular.fiscal_year;

-- Note that this PIVOT query originally refered to years 2002-2004, which jived with
-- earlier versions of the AdventureWorks data.  Somewhere along the way all the dates
-- were cranked forward by exactly a decade, but this view wasn't updated, effectively
-- breaking it.  The hard-coded fiscal years below fix this issue.

-- Current sales data ranges from May 31, 2011 through June 30, 2014, so there's one
-- month of fiscal year 2011 data, but mostly FY 2012 through 2014.

-- This query properly shows no data for three of our sales people in 2012,
-- as they were hired during FY 2013.
create view sales.v_sales_person_sales_by_fiscal_years
as
select * from crosstab(
'select
    sales_person_id
    ,full_name
    ,job_title
    ,sales_territory
    ,fiscal_year
    ,sales_total
from sales.v_sales_person_sales_by_fiscal_years_data
order by 2,4'
-- This set of fiscal years could have dynamically come from a SELECT DISTINCT,
-- but we wanted to omit 2011 and also ...
,$$_select unnest('{2012,2013,2014}'::text[])$$)
-- ... still the FiscalYear values have to be hard-coded here.
as sales_total ("sales_person_id" integer, "full_name" text, "job_title" text, "sales_territory" text,
 "2012" decimal(12, 4), "2013" decimal(12, 4), "2014" decimal(12, 4));


create materialized view person.v_state_province_country_region
as
select
    sp.state_province_id
    ,sp.state_province_code
    ,sp.is_only_state_province_flag
    ,sp.name as state_province_name
    ,sp.territory_id
    ,cr.country_region_code
    ,cr.name as country_region_name
from person.state_province sp
    inner join person.country_region cr
    on sp.country_region_code = cr.country_region_code;

create unique index ix_v_state_province_country_region on person.v_state_province_country_region(state_province_id, country_region_code);
cluster person.v_state_province_country_region using ix_v_state_province_country_region;
-- If there are changes to either of these tables, this should be run to update the view:
--   REFRESH MATERIALIZED VIEW production.v_state_province_country_region;


create view sales.v_store_with_demographics
as
select
    business_entity_id
    ,name
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:AnnualSales/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS money)
                                       AS "annual_sales"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:AnnualRevenue/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS money)
                                       AS "annual_revenue"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:BankName/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(50)
                                  AS "bank_name"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:BusinessType/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(5)
                                  AS "business_type"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:YearOpened/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "year_opened"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Specialty/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(50)
                                  AS "specialty"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:SquareFeet/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "square_feet"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Brands/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(30)
                                  AS "brands"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Internet/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(30)
                                  AS "internet"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:NumberEmployees/text()', demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "number_employees"
from sales.store;


create view sales.v_store_with_contacts
as
select
    s.business_entity_id
    ,s.name
    ,ct.name as contact_type
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,pp.phone_number
    ,pnt.name as phone_number_type
    ,ea.email_address
    ,p.email_promotion
from sales.store s
  inner join person.business_entity_contact bec
    on bec.business_entity_id = s.business_entity_id
  inner join person.contact_type ct
    on ct.contact_type_id = bec.contact_type_id
  inner join person.person p
    on p.business_entity_id = bec.person_id
  left outer join person.email_address ea
    on ea.business_entity_id = p.business_entity_id
  left outer join person.person_phone pp
    on pp.business_entity_id = p.business_entity_id
  left outer join person.phone_number_type pnt
    on pnt.phone_number_type_id = pp.phone_number_type_id;


create view sales.v_store_with_addresses
as
select
    s.business_entity_id
    ,s.name
    ,at.name as address_type
    ,a.address_line1
    ,a.address_line2
    ,a.city
    ,sp.name as state_province_name
    ,a.postal_code
    ,cr.name as country_region_name
from sales.store s
  inner join person.business_entity_address bea
    on bea.business_entity_id = s.business_entity_id
  inner join person.address a
    on a.address_id = bea.address_id
  inner join person.state_province sp
    on sp.state_province_id = a.state_province_id
  inner join person.country_region cr
    on cr.country_region_code = sp.country_region_code
  inner join person.address_type at
    on at.address_type_id = bea.address_type_id;


create view purchasing.v_vendor_with_contacts
as
select
    v.business_entity_id
    ,v.name
    ,ct.name as contact_type
    ,p.title
    ,p.first_name
    ,p.middle_name
    ,p.last_name
    ,p.suffix
    ,pp.phone_number
    ,pnt.name as phone_number_type
    ,ea.email_address
    ,p.email_promotion
from purchasing.vendor v
  inner join person.business_entity_contact bec
    on bec.business_entity_id = v.business_entity_id
  inner join person.contact_type ct
    on ct.contact_type_id = bec.contact_type_id
  inner join person.person p
    on p.business_entity_id = bec.person_id
  left outer join person.email_address ea
    on ea.business_entity_id = p.business_entity_id
  left outer join person.person_phone pp
    on pp.business_entity_id = p.business_entity_id
  left outer join person.phone_number_type pnt
    on pnt.phone_number_type_id = pp.phone_number_type_id;


create view purchasing.v_vendor_with_addresses
as
select
    v.business_entity_id
    ,v.name
    ,at.name as address_type
    ,a.address_line1
    ,a.address_line2
    ,a.city
    ,sp.name as state_province_name
    ,a.postal_code
    ,cr.name as country_region_name
from purchasing.vendor v
  inner join person.business_entity_address bea
    on bea.business_entity_id = v.business_entity_id
  inner join person.address a
    on a.address_id = bea.address_id
  inner join person.state_province sp
    on sp.state_province_id = a.state_province_id
  inner join person.country_region cr
    on cr.country_region_code = sp.country_region_code
  inner join person.address_type at
    on at.address_type_id = bea.address_type_id;


-- Convenience views

create schema pe
  create view a as select address_id as id, * from person.address
  create view at as select address_type_id as id, * from person.address_type
  create view be as select business_entity_id as id, * from person.business_entity
  create view bea as select business_entity_id as id, * from person.business_entity_address
  create view bec as select business_entity_id as id, * from person.business_entity_contact
  create view ct as select contact_type_id as id, * from person.contact_type
  create view cr as select * from person.country_region
  create view e as select email_address_id as id, * from person.email_address
  create view pa as select business_entity_id as id, * from person.password
  create view p as select business_entity_id as id, * from person.person
  create view pp as select business_entity_id as id, * from person.person_phone
  create view pnt as select phone_number_type_id as id, * from person.phone_number_type
  create view sp as select state_province_id as id, * from person.state_province
;
create schema hr
  create view d as select department_id as id, * from human_resources.department
  create view e as select business_entity_id as id, * from human_resources.employee
  create view edh as select business_entity_id as id, * from human_resources.employee_department_history
  create view eph as select business_entity_id as id, * from human_resources.employee_pay_history
  create view jc as select job_candidate_id as id, * from human_resources.job_candidate
  create view s as select shift_id as id, * from human_resources.shift
;
create schema pr
  create view bom as select bill_of_materials_id as id, * from production.bill_of_materials
  create view c as select culture_id as id, * from production.culture
  create view d as select * from production.document
  create view i as select illustration_id as id, * from production.illustration
  create view l as select location_id as id, * from production.location
  create view p as select product_id as id, * from production.product
  create view pc as select product_category_id as id, * from production.product_category
  create view pch as select product_id as id, * from production.product_cost_history
  create view pd as select product_description_id as id, * from production.product_description
  create view pdoc as select product_id as id, * from production.product_document
  create view pi as select product_id as id, * from production.product_inventory
  create view plph as select product_id as id, * from production.product_list_price_history
  create view pm as select product_model_id as id, * from production.product_model
  create view pmi as select * from production.product_model_illustration
  create view pmpdc as select * from production.product_model_product_description_culture
  create view pp as select product_photo_id as id, * from production.product_photo
  create view ppp as select * from production.product_product_photo
  create view pr as select product_review_id as id, * from production.product_review
  create view psc as select product_subcategory_id as id, * from production.product_subcategory
  create view sr as select scrap_reason_id as id, * from production.scrap_reason
  create view th as select transaction_id as id, * from production.transaction_history
  create view tha as select transaction_id as id, * from production.transaction_history_archive
  create view um as select unit_measure_code as id, * from production.unit_measure
  create view w as select work_order_id as id, * from production.work_order
  create view wr as select work_order_id as id, * from production.work_order_routing
;
create schema pu
  create view pv as select product_id as id, * from purchasing.product_vendor
  create view pod as select purchase_order_detail_id as id, * from purchasing.purchase_order_detail
  create view poh as select purchase_order_id as id, * from purchasing.purchase_order_header
  create view sm as select ship_method_id as id, * from purchasing.ship_method
  create view v as select business_entity_id as id, * from purchasing.vendor
;
create schema sa
  create view crc as select * from sales.country_region_currency
  create view cc as select credit_card_id as id, * from sales.credit_card
  create view cu as select currency_code as id, * from sales.currency
  create view cr as select * from sales.currency_rate
  create view c as select customer_id as id, * from sales.customer
  create view pcc as select business_entity_id as id, * from sales.person_credit_card
  create view sod as select sales_order_detail_id as id, * from sales.sales_order_detail
  create view soh as select sales_order_id as id, * from sales.sales_order_header
  create view sohsr as select * from sales.sales_order_header_sales_reason
  create view sp as select business_entity_id as id, * from sales.sales_person
  create view spqh as select business_entity_id as id, * from sales.sales_person_quota_history
  create view sr as select sales_reason_id as id, * from sales.sales_reason
  create view tr as select sales_tax_rate_id as id, * from sales.sales_tax_rate
  create view st as select territory_id as id, * from sales.sales_territory
  create view sth as select territory_id as id, * from sales.sales_territory_history
  create view sci as select shopping_cart_item_id as id, * from sales.shopping_cart_item
  create view so as select special_offer_id as id, * from sales.special_offer
  create view sop as select special_offer_id as id, * from sales.special_offer_product
  create view s as select business_entity_id as id, * from sales.store
;

\pset tuples_only off



-- 805 rows in BusinessEntity but not in Person
-- SELECT be.business_entity_id FROM person.businessentity AS be LEFT OUTER JOIN person.person AS p ON be.business_entity_id = p.business_entity_id WHERE p.business_entity_id IS NULL;

-- All the tables in Adventureworks:
-- (Did you know that \dt can filter schema and table names using RegEx?)
\dt (human_resources|person|production|purchasing|sales).*
