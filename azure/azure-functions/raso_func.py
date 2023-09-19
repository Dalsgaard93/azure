import logging
import os, sys, uuid
import json
# import requests

 

# pip install azure-storage-file-datalake --pre
import azure.functions as func
from datetime import date, datetime as DateObj

 

sql_server           = 'xxxxxxx'
azuredb_sql_user_raw = 'xxxxxxxxx'
azuredb_sql_user     = '{azuredb_sql_user_raw}@{sql_server}'.format(azuredb_sql_user_raw=azuredb_sql_user_raw, sql_server=sql_server)
azuredb_sql_pass     = 'xxxxxxx'

 

def get_ODBC_ConnectionString(targetdb):
  odbc_conStr = 'DRIVER={ODBC Driver 17 for SQL Server};' + 'SERVER={sql_server}.database.windows.net,1433;DATABASE={targetdb};UID={azuredb_sql_user};PWD={azuredb_sql_pass}'.format(sql_server=sql_server, targetdb=targetdb, azuredb_sql_user=azuredb_sql_user, azuredb_sql_pass=azuredb_sql_pass)
  return odbc_conStr

 

odbc_conStr_dataimport          =  get_ODBC_ConnectionString('DBNamexxxxxxxxx')

 

def SQL_GetDF_from_AzureDB(constr, sql):
  import pandas
  import pyodbc
  cnxn = pyodbc.connect(constr)
  data = pandas.read_sql(sql,cnxn)
  return data

 

def get_SQL_for_Articles(article_date):
    sql_to_run =  """
        SELECT *
        FROM [Cue].[Cue_Articles]
        where 1=1
        and CONVERT(INT, CONVERT(VARCHAR(8), cast(cast([EnqueuedTimeUtc] as datetime) as date), 112)) = {article_date}
    """.format(article_date = article_date)
    return sql_to_run

 

def main(req: func.HttpRequest) -> func.HttpResponse:

    returnObject = json.dumps({})

 

    # Handle Local Development
    if os.getenv("running_in_azure") is None:
        os.environ["running_as"] = "Development";

    logging.info("*** Received article request. ({0})".format(os.environ["running_as"]))

    # # OLD but keep for REST API POST Azure Functions: Parse request inputs from BODY
    # try:
    #     rawbody = req.get_body()
    #     logging.info('*** rawbody = {rawbody} ****'.format(rawbody = rawbody))
    #     body = json.loads(rawbody)
    #     logging.info('*** Input Data modtaget: {0}'.format(req.get_body()))
    # except Exception as e:
    #     logging.error("*** JSON Body is not parse-able: {0}".format(e))
    #     return func.HttpResponse(
    #             # "*** Succesfuldt overført Iteras Webhook til Azure Data Lake",
    #             rawbody, 
    #             status_code=200
    #     )

 

    # Iters the customer/campaign changes in the body recieved from iteras are provided
    # as lists, thus, we iterate over each change get full record and save record to lake

 

    # if body:
    #     try:
    #         article_date = body["article_date"]
    #         borsen_site = body["borsen_site"]
    #     except Exception as e:
    #         logging.error("*** Required parameters could not be extracted from body, message: {0}".format(e))
    #         return

 

    # If there are parameters in the GET request (apart from the code to the Az Function itself), parse them here,
    if req and req.params and "article_date" in req.params:
        article_date = req.params["article_date"]
        try:
            df = SQL_GetDF_from_AzureDB(odbc_conStr_dataimport, get_SQL_for_Articles(article_date))
            logging.info("*** Number of rows/articles found: {0}".format(len(df.index)))
            returnObject = df.to_json(orient="table")
        except Exception as e:
            logging.error("*** Could not call AzureDB, ERROR MESSAGE: {0}".format(e))    

        return func.HttpResponse(
                # "*** Succesfuldt overført Iteras Webhook til Azure Data Lake",
                returnObject, 
                mimetype="application/json",
                status_code=200
        )

    err_msg =  "*** Required parameters 'article_date' (Datekey format needed YYYYMMDD) ***"
    logging.error(err_msg)
    returnObject = json.dumps({"Error": err_msg})
    return func.HttpResponse(
        returnObject, 
        mimetype="application/json",
        status_code=400
    )