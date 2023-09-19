#import azure.functions as func
import logging
import requests 
import numpy as np
import json

#app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)
    
sql_server           = 'server-for-web-db'
azuredb_sql_user_raw = 'integrationadmin'
azuredb_sql_user     = '{azuredb_sql_user_raw}@{sql_server}'.format(azuredb_sql_user_raw=azuredb_sql_user_raw, sql_server=sql_server)
azuredb_sql_pass     = 'AE55965F58D2CA359FB9A8B094850537a!'

def get_ODBC_ConnectionString(targetdb):
    odbc_conStr = 'DRIVER={ODBC Driver 17 for SQL Server};' + f'SERVER={sql_server}.database.windows.net,1433;DATABASE={targetdb};UID={azuredb_sql_user_raw};PWD={azuredb_sql_pass}'
    print(odbc_conStr)
    return odbc_conStr

odbc_conStr_dataimport = get_ODBC_ConnectionString('consent-token-db')

def get_df_from_SQL(constr, sql):
    import pandas
    import pyodbc
    cnxn = pyodbc.connect(constr)
    data = pandas.read_sql(sql,cnxn)
    return data

def write_to_SQL(constr, write_sql):
    import pyodbc
    cnxn = pyodbc.connect(constr)
    cursor = cnxn.cursor()
    cursor.execute(write_sql)
    cnxn.commit()

def sqlGetTokenPair():
    sql_to_run =  """
        SELECT top 1 [access_token]
                    ,[refresh_token]
        FROM [dbo].[token_table_aiia]
        order by id desc
    """
    return sql_to_run

def sqlInsertTokenPairToDB(access_token, refresh_token):
    sql_to_run =  f"""
        INSERT INTO [dbo].[token_table_aiia]
           ([access_token]
           ,[refresh_token])
        VALUES
           ('{access_token}'
           ,'{refresh_token}')
    """
    return sql_to_run

def sqlInsert_aiia_transaction_ToDB(transaction_id, transaction_json):
    sql_to_run =  f"""
        INSERT INTO [dbo].[aiia_transactions]
           ([transaction_id]
           ,[transaction_json])
        VALUES
           ('{transaction_id}'
           ,'{transaction_json}')
    """
    return sql_to_run

def sqlInsert_economic_customers_ToDB(customer_no, customer_json):
    sql_to_run =  f"""
        INSERT INTO [dbo].[economic_customers]
           ([customer_no]
           ,[customer_json])
        VALUES
           ('{customer_no}'
           ,'{customer_json}')
    """
    return sql_to_run

def get_unwrapped_tokens():
    token_pair = get_df_from_SQL(odbc_conStr_dataimport, sqlGetTokenPair())
    access_token = token_pair['access_token']
    refresh_token = token_pair['refresh_token']
    return access_token, refresh_token

if __name__ == '__main__':

    code = 'ygAAAAVDaXBoZXJ0ZXh0AJAAAAAAyCJNHt1xd8HmO4JzabHOPgnkRBivoqd7Gh9ouZkC6dTjPpJ0a0nPnN1MeA5s/Ior5dFK0orwYACxzqoRjRXSt+N8Wl9mHxLn5xrWLKwIgyx8CM4Ivnd0thlU7kHIy/+Z89ik92yd0ZGQBySyL9k446PlEO/vNJIlXE0SkBIl+OXg8pkvxE7WUwbeN9dfSrCcBUl2ABAAAAAAMkUhn9vm+WFn6F8vx4EN6BBLZXlJZAAAAAAAAA=='

    url = 'https://api-sandbox.aiia.eu/v1/oauth/token'

    user = {
        'user' : 'aiiapoc-92cd7c26-3ca6-404d-9b1c-3dee11a15c81',
        'pw' : '6e6c150ebcb36f90e8cd5c750c8c0ca42a8751b7d63f0110a465115dff4dec86'
    }

    headers = {
        'Content-Type': 'application/json'
    }

    data = {
        'grant_type' : 'authorization_code',
        'code' : code,
        'redirect_uri' : 'https://aiia-test-site.azurewebsites.net/'
    }

    response = requests.post(url, auth=(user['user'], user['pw']), headers=headers, json=data )

    new_access_token = response.json().get('access_token')
    new_refresh_token = response.json().get('refresh_token')

    write_to_SQL(odbc_conStr_dataimport, sqlInsertTokenPairToDB(new_access_token, new_refresh_token))

    print(response.status_code)
    print('Response')
    print(response.json())
