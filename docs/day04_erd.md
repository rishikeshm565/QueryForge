\# QueryForge ERD — Day 4



```mermaid

erDiagram



&#x20;   CUSTOMERS ||--|| CUSTOMER\_PROFILES : has

&#x20;   CUSTOMERS ||--o{ ORDERS : places



&#x20;   ORDERS ||--o{ ORDER\_ITEMS : contains

&#x20;   PRODUCTS ||--o{ ORDER\_ITEMS : appears\_in



&#x20;   CUSTOMERS {

&#x20;       INTEGER customer\_id PK

&#x20;       VARCHAR full\_name

&#x20;       VARCHAR email

&#x20;   }



&#x20;   CUSTOMER\_PROFILES {

&#x20;       INTEGER customer\_id PK, FK

&#x20;       TEXT address

&#x20;       VARCHAR preferred\_language

&#x20;       VARCHAR loyalty\_level

&#x20;   }



&#x20;   ORDERS {

&#x20;       INTEGER order\_id PK

&#x20;       INTEGER customer\_id FK

&#x20;       DATE order\_date

&#x20;       VARCHAR order\_status

&#x20;       NUMERIC total\_amount

&#x20;   }



&#x20;   PRODUCTS {

&#x20;       INTEGER product\_id PK

&#x20;       VARCHAR product\_name

&#x20;       NUMERIC unit\_price

&#x20;       BOOLEAN is\_active

&#x20;   }



&#x20;   ORDER\_ITEMS {

&#x20;       INTEGER order\_id PK, FK

&#x20;       INTEGER product\_id PK, FK

&#x20;       INTEGER quantity

&#x20;       NUMERIC unit\_price

&#x20;   }

```

