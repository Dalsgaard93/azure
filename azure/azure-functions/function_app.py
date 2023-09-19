import azure.functions as func
import logging
import requests 
import json

import sql_functions as sf

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="AiiaRefreshToken", auth_level=func.AuthLevel.FUNCTION)
def AiiaRefreshToken(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request for aiia.')

    token_pair = sf.get_df_from_SQL(sf.odbc_conStr_dataimport, sf.sqlGetTokenPair())
    access_token = token_pair.iloc[0].values[0]
    refresh_token = token_pair.iloc[0].values[1]

    url = 'https://api-sandbox.aiia.eu/v1/oauth/token'

    user = {
        'user' : 'aiiapoc-92cd7c26-3ca6-404d-9b1c-3dee11a15c81',
        'pw' : '6e6c150ebcb36f90e8cd5c750c8c0ca42a8751b7d63f0110a465115dff4dec86'
    }

    headers = {
        'Content-Type': 'application/json'
    }

    data = {
        'grant_type' : 'refresh_token',
        'refresh_token' : refresh_token
    }

    response = requests.post(url, auth=(user['user'], user['pw']), headers=headers, json=data )

    new_access_token = response.json().get('access_token')
    new_refresh_token = response.json().get('refresh_token')

    sf.write_to_SQL(sf.odbc_conStr_dataimport, sf.sqlInsertTokenPairToDB(new_access_token, new_refresh_token))

    return func.HttpResponse('Refresh aiia token request processed successfully.', status_code=200)

@app.route(route="AiiaGetAccounts", auth_level=func.AuthLevel.FUNCTION)
def AiiaGetAccounts(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    token_pair = sf.get_df_from_SQL(sf.odbc_conStr_dataimport, sf.sqlGetTokenPair())
    access_token = token_pair.iloc[0].values[0]

    url = 'https://api-sandbox.aiia.eu/v1/accounts'

    headers = {
        'Authorization': 'Bearer '+str(access_token),
        'X-Client-Id' : 'aiiapoc-92cd7c26-3ca6-404d-9b1c-3dee11a15c81',
        'X-Client-Secret' : '6e6c150ebcb36f90e8cd5c750c8c0ca42a8751b7d63f0110a465115dff4dec86'
    }

    response = requests.get(url, headers=headers)

    #logging.info(response.json())
    print(response.status_code)
    print('Response')
    print(response.json())
    return func.HttpResponse('Get aiia accounts request processed successfully.', status_code=200)

@app.route(route="AiiaGetTransactions", auth_level=func.AuthLevel.FUNCTION)
def AiiaGetTransactions(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    token_pair = sf.get_df_from_SQL(sf.odbc_conStr_dataimport, sf.sqlGetTokenPair())
    access_token = token_pair.iloc[0].values[0]

    account_id = 'MjI2ZTk2ODgtNWU4MC00ZjIxLWI2NTUtNmFjYWEzMWYxOGYxfERlbW9CYW5rfHhsa19IdGFnOTBvT3NNclRXeXFISTFtQUFrYW1jVkJaWDA2X3EtVS1XQm8uMjMxNGM5MTYzMjEw'

    url = 'https://api-sandbox.aiia.eu/v1/accounts/'+account_id+'/transactions'

    headers = {
        'Authorization': 'Bearer '+str(access_token),
        'X-Client-Id' : 'aiiapoc-92cd7c26-3ca6-404d-9b1c-3dee11a15c81',
        'X-Client-Secret' : '6e6c150ebcb36f90e8cd5c750c8c0ca42a8751b7d63f0110a465115dff4dec86'
    }

    response = requests.get(url, headers=headers)

    for r in response.json()['transactions']:
        r_string = json.dumps(r)
        sf.write_to_SQL(sf.odbc_conStr_dataimport, sf.sqlInsert_aiia_transaction_ToDB(r['id'],r_string))

    return func.HttpResponse('Get aiia transactions request processed successfully.', status_code=200)

@app.route(route="EconomicGetCustomers", auth_level=func.AuthLevel.FUNCTION)
def EconomicGetCustomers(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Requesting customers list.')

    url = 'https://restapi.e-conomic.com/customers'

    headers = {
        'X-AppSecretToken': 'SqBTvRKseCPji5pIH6UD0JaCE4mj7VBnpPqtIdMrYew1',
        'X-AgreementGrantToken': 'oHvYSlDdAYjCcfDMuDep2zY0ImBeHic4yMFtPHxbk141',
        'Content-Type': 'application/json'
    }

    response = requests.get(url, headers=headers)

    for c in response.json()['collection']:
        c_string = json.dumps(c)
        sf.write_to_SQL(sf.odbc_conStr_dataimport, sf.sqlInsert_economic_customers_ToDB(c['customerNumber'],c_string))

    return func.HttpResponse('Get economic customers request processed successfully.', status_code=200)
