ip: 122.248.235.218
port: 5432
name: churnobyl
user: churnuser
password: fcchurnpass

TODO:



- jquery date picker - 30 mins


--  scenario
--- 1.  I click on general branch and get a list of lead organisers with selection showing as general branch
--- 2.  I click on tim gunstone and get a list of companies with selection as general branch and tim gunstone

- export member detail
- password so we can host on heroku
- bundler ease deployment to ubuntu on amazon
-- removing a selection (or they can go back)

DONE: 

- sub total drop down - 20 mins
-- BranchID = Branch
-- Lead = Lead Organiser
-- Org = Organiser
-- AreaID = Area
-- companyid = Work Site
-- IndustryID = Industry
-- Del = Delegate training
-- HSR = HSR training
-- NUWElectorate = Electorate
-- State = State
-- feegroup = Fee Group

- keep track of filters when drilling down
- show filter history as a set of tags with nice names not ids

- sensible subtotal/groupby change on drilldown - define 30 mins
-- Home -> Branch
-- Branch -> Lead
-- Lead -> Org
-- Org -> CompanyID
-- State -> Area
-- Area -> CompanyID
-- FeeGroup -> CompanyID
-- NUW Electorate -> Org
-- Del -> CompanyID (experiment)
-- HSR -> CompanyID (experiment)
