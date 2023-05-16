#!/usr/bin/env python
# coding: utf-8

# # Photovoltaics at simons.ac

# In[ ]:


import duckdb
import pandas as pd
import matplotlib.pyplot as plt
db = duckdb.connect(database=':memory:')
db.sql('INSTALL httpfs')
db.sql('LOAD httpfs')
db.sql("IMPORT database 'http://simons.ac/pv'")

# You can also use a local db with the required tables and views installed as shown in the README.md
# db = duckdb.connect('pv.db')


# Until September 2022 we successfully dodged COVID - despite having 2 kids in school… Being bound to the house, we finally had some time to think about doing something with regard energy supply in our house and possible future plans of replacing the natural-gas based heating.
# 
# Both gas and electricy have been erratic since the Russian invasion into Ukraine since February the same year anyway and with the increasing inflation… Well let's say, more than 75% increase since we moved into our house speaks for its own:

# In[ ]:


buying_prices = db.sql("SELECT valid_from AS year, net FROM buying_prices").df()
imported = db.sql("SELECT date_trunc('year', period_end) as year, import FROM official_measurements ORDER by period_start ASC").df()

imported_with_price = pd.merge_asof(buying_prices, imported, on="year")

_, ax = plt.subplots()
imported_with_price.plot(x = 'year', y = 'net',    ylabel='Net price in ct/kWh', ax = ax)
imported_with_price.plot(x = 'year', y = 'import', ylabel='Imported energy in kWh', ax = ax, secondary_y = True)


# The import value did stay relative constant over the years. You hardly notice the increase when I began working remotely for Neo4j back in 2018. Heck, I even think that the increase is more the result of my kids playing Fortnite and friends like crazy.

# ## The setup
# 
# We went for an installation of 10.53kWp, in a split east/west setup. In total we have 26 [Solarwatt Glass-Glass "Panel Vision AM 4.0"](https://d1c96hlcey6qkb.cloudfront.net/1ca87037-d8ca-4c95-afc6-31a40af9baa7/12f29964ea22459284824ba88d376706?response-content-disposition=inline%3B%20filename%2A%3DUTF-8%27%27Datenblatt%2520SOLARWATT%2520Panel%2520vision%2520AM%25204.0%2520pure%2520de.pdf&response-content-type=application%2Fpdf&Expires=1684368000&Signature=EY4ik3laxfaoPNyRxeicP83MqJ39kiPCC3KsfpXSctFSB~ldduZPmhL-LSuy-4ZLQIkLSp5bMq6tEAU-D1eLTmkCY-VW59YRy24-vtSS~zfjECk7JaidFut~M3ZuXDqNBcGNewFBjxID6nNthoDOlEkKwn-FZzop8~2gDjiONdM0min61ltQaN8JuiZj-Zve49lXVZdiiI06TCpaaSW5-qg3FnNouAgshPeU8geJfOz6t4VOxgy0t7ux6aYO29bmR8m1TIBN8FEwu2ivPbotCNh~qSdFjtO7PHubr4oajyl9Ox2s5p2oC5wTl5uZxdp0fwX~woqOwuQAC6yEwk3zig__&Key-Pair-Id=APKAI33AGAEAYCXFBDTA) modules with an output of 405Wp each, in plus selection:
# 
# * 14 directed east
# * 12 directed west
# 
# The inverter is a Kaco [blueplanet 10.0 NX3 M2](https://kaco-newenergy.com/de/produkte/blueplanet-3.0-20.0-NX3-M2/)
# 
# We had a bit of an issue with the smart monitoring and the electrician and in the end, I created this [logger](https://github.com/michael-simons/pv/tree/main/logger) that dumps the current wattage from the SunSpec compatible modbus device attached with the inverter and after that, I went a bit crazy with analyzing the values with the help of [DuckDB](https://duckdb.org).
# 
# While I could have expressed all the queries in this notebook directly, I went more for a subset of the [pink database design](https://www.salvis.com/blog/2018/07/18/the-pink-database-paradigm-pinkdb/#feature_3) and created a bunch of views that I prefer querying here (and in the shell).

# In[ ]:


min_max = db.sql('SELECT min(measured_on) AS min, max(measured_on) AS max FROM production')


# ## The results
# 
# The measurement in the currently loaded dataset spans right now from

# In[ ]:


"{} to {}".format(min_max.df()['min'][0].strftime('%Y-%m-%d'), min_max.df()['max'][0].strftime('%Y-%m-%d'))


# In that period we had the following overall production:

# In[ ]:


db.sql('SELECT * FROM overall_production').df()


# with averages per month as follows:

# In[ ]:


average_per_month = db.sql('SELECT * FROM average_production_per_month').df()[['Month', 'kWh']].dropna()
average_per_month.plot(kind='bar', x='Month')


# As of writing, we still haven't had any day really close to possible peak. However, our original assumption that we are better of using both side of the house holds true. The inverter boots up pretty close to sunrise and already in May we had several evenings where the whole setup was producing enough energy for cooking. Plotting the production per hour shows that:

# In[ ]:


average_per_hour = db.sql('SELECT * FROM average_production_per_hour').df()[['Hour', 'kWh']].dropna()
average_per_hour.plot(kind='barh', x='Hour').invert_yaxis()


# The production for the best performing day so far looks like this:

# In[ ]:


db.sql('SELECT * FROM best_performing_day').df().plot(x='measured_on', y='power', ylabel='W')

