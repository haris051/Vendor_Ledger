drop procedure if Exists PROC_VENDER_LEDGER;
DELIMITER $$
CREATE PROCEDURE `PROC_VENDER_LEDGER`( P_VENDOR_ID TEXT,
									  P_ENTRY_DATE_FROM TEXT,
									  P_ENTRY_DATE_TO TEXT,
									  P_FORM_TYPE TEXT,
									  P_START INT,
									  P_LENGTH INT,
                                      P_COMPANY_ID INT )
BEGIN

	DECLARE BEGININGBALANCE DECIMAL(22, 2) DEFAULT 0;

	IF P_FORM_TYPE = "" THEN
		SET P_FORM_TYPE = '-1';
    END IF;
    
    -- =========== Beginning Balance ===========
    
	SELECT CASE
				WHEN ENTRY_DATE IS NOT NULL THEN SUM(BALANCE)
				ELSE IFNULL(SUM(DEBIT), 0) - IFNULL(SUM(CREDIT), 0)
		   END AS BALANCE INTO BEGININGBALANCE
	  FROM (SELECT VENDOR_ID,
				   ENTRY_DATE,
				   PAYPAL_TRANSACTION_ID,
				   FLAG,
				   FORM,
				   DEBIT,
				   CREDIT,
				   FINAL AS BALANCE
				   -- SUM(FINAL) OVER (PARTITION BY VENDOR_ID ORDER BY VENDOR_ID, ENTRY_DATE, PAYPAL_TRANSACTION_ID, FLAG, FORM, DEBIT, CREDIT, FINAL) AS BALANCE
			  FROM ( SELECT B.VENDOR_ID, 
							A.VCM_ENTRY_DATE AS ENTRY_DATE, 
							A.PAYPAL_TRANSACTION_ID, 
							'V' AS FLAG, 
							'Vendor Credit Memo' AS FORM,
							SUM(A.VCM_TOTAL) AS DEBIT,
							NULL AS CREDIT,
							SUM(A.VCM_TOTAL) AS FINAL
					   FROM VENDOR_CREDIT_MEMO A,
							VENDOR B
					  WHERE A.VENDOR_ID = B.ID
						AND  CASE
							   WHEN P_ENTRY_DATE_FROM <> "" THEN A.VCM_ENTRY_DATE < P_ENTRY_DATE_FROM
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_VENDOR_ID <> "" THEN B.ID = P_VENDOR_ID
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_COMPANY_ID <> "" THEN A.COMPANY_ID = P_COMPANY_ID
							   ELSE TRUE
							END
				   GROUP BY B.VENDOR_ID, A.VCM_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID
						 
					 UNION ALL 
				   
					 SELECT B.VENDOR_ID, 
							A.RECEIVE_ENTRY_DATE AS ENTRY_DATE, 
							A.PAYPAL_TRANSACTION_ID AS PAYPAL_TRANSACTION_ID, 
							'R' AS FLAG, 
							'Receive Order' AS FORM,
							NULL AS DEBIT,
							SUM(A.RECEIVE_TOTAL_AMOUNT ) AS CREDIT,
							SUM(A.RECEIVE_TOTAL_AMOUNT *-1) AS FINAL
					   FROM RECEIVE_ORDER A,
							VENDOR B
					  WHERE A.VENDOR_ID = B.ID
						AND  CASE
							   WHEN P_ENTRY_DATE_FROM <> "" THEN A.RECEIVE_ENTRY_DATE < P_ENTRY_DATE_FROM
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_VENDOR_ID <> "" THEN B.ID = P_VENDOR_ID
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_COMPANY_ID <> "" THEN A.COMPANY_ID = P_COMPANY_ID
							   ELSE TRUE
							END
				   GROUP BY B.VENDOR_ID, A.RECEIVE_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID
						  
					 UNION ALL
					
					 SELECT B.VENDOR_ID, 
							A.PS_ENTRY_DATE AS ENTRY_DATE, 
							A.PAYPAL_TRANSACTION_ID, 
							'P' AS FLAG,
							'Payment Sent' AS FORM,
							SUM(A.AMOUNT) AS DEBIT,
							NULL AS CREDIT,
							SUM(A.AMOUNT) AS FINAL
					   FROM PAYMENT_SENT A,
							VENDOR B
					  WHERE A.VENDOR_ID = B.ID
						AND CASE
							   WHEN P_ENTRY_DATE_FROM <> "" THEN A.PS_ENTRY_DATE < P_ENTRY_DATE_FROM
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_VENDOR_ID <> "" THEN B.ID = P_VENDOR_ID
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_COMPANY_ID <> "" THEN A.COMPANY_ID = P_COMPANY_ID
							   ELSE TRUE
							END
				   GROUP BY B.VENDOR_ID, A.PS_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID
						  
					 UNION ALL 
					
					 SELECT B.VENDOR_ID, 
							A.PC_ENTRY_DATE AS ENTRY_DATE, 
							A.PAYPAL_TRANSACTION_ID, 
							'C' AS FLAG, 
							'Partial Credit' AS FORM,
							SUM(A.TOTAL_AMOUNT) AS DEBIT,
							NULL AS CREDIT,
							SUM(A.TOTAL_AMOUNT * -1) AS FINAL
					   FROM PARTIAL_CREDIT A,
							VENDOR B
					  WHERE A.VENDOR_ID = B.ID
						AND CASE
							   WHEN P_ENTRY_DATE_FROM <> "" THEN A.PC_ENTRY_DATE < P_ENTRY_DATE_FROM
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_VENDOR_ID <> "" THEN B.ID = P_VENDOR_ID
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_COMPANY_ID <> "" THEN A.COMPANY_ID = P_COMPANY_ID
							   ELSE TRUE
							END
				   GROUP BY B.VENDOR_ID, A.PC_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID
				   
					 UNION ALL

					 SELECT B.VENDOR_ID, 
							A.RM_ENTRY_DATE AS ENTRY_DATE, 
							A.PAYPAL_TRANSACTION_ID, 
							'M' AS FLAG, 
							'Receive Money' AS FORM,
							NULL AS DEBIT,
							SUM(A.AMOUNT ) AS CREDIT,
							SUM(A.AMOUNT * -1) AS FINAL
					   FROM RECEIVE_MONEY A,
							VENDOR B
					  WHERE A.VENDOR_ID = B.ID
						AND  CASE
							   WHEN P_ENTRY_DATE_FROM <> "" THEN A.RM_ENTRY_DATE < P_ENTRY_DATE_FROM
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_VENDOR_ID <> "" THEN B.ID = P_VENDOR_ID
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_COMPANY_ID <> "" THEN A.COMPANY_ID = P_COMPANY_ID
							   ELSE TRUE
							END
				   GROUP BY B.VENDOR_ID, A.RM_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID
				   
					 UNION ALL
				   
					 SELECT B.VENDOR_ID, 
							A.PAY_ENTRY_DATE AS ENTRY_DATE, 
							A.PAY_REFERENCE, 
							'O' AS FLAG, 
							'Vendor Payment' AS FORM,
							CASE 
								WHEN A.REMAINING_AMOUNT > 0 THEN SUM(ABS(A.REMAINING_AMOUNT)) 
								ELSE NULL 
							END AS DEBIT,
							CASE 
								WHEN A.REMAINING_AMOUNT < 0 THEN SUM(ABS(A.REMAINING_AMOUNT)) 
								ELSE NULL  
							END AS CREDIT,
							CASE 
								WHEN A.REMAINING_AMOUNT > 0 THEN SUM(ABS(A.REMAINING_AMOUNT)) 
								ELSE SUM(ABS(A.REMAINING_AMOUNT) * -1)
							END AS FINAL
					   FROM PAYMENTS A,
							VENDOR B
					  WHERE A.VENDOR_ID = B.ID
						AND A.REMAINING_AMOUNT <> 0
						AND  CASE
							   WHEN P_ENTRY_DATE_FROM <> "" THEN A.PAY_ENTRY_DATE < P_ENTRY_DATE_FROM
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_VENDOR_ID <> "" THEN B.ID = P_VENDOR_ID
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_COMPANY_ID <> "" THEN A.COMPANY_ID = P_COMPANY_ID
							   ELSE TRUE
							END
				   GROUP BY B.VENDOR_ID, A.PAY_ENTRY_DATE, A.PAY_REFERENCE
				   
					 UNION ALL 
				   
					 SELECT B.VENDOR_ID, 
							A.SN_ENTRY_DATE AS ENTRY_DATE, 
							A.SN_ID AS PAYPAL_TRANSACTION_ID, 
							'N' AS FLAG, 
							'Stock In' AS FORM,
							NULL AS DEBIT,
							SUM(A.TOTAL_AMOUNT_IN ) AS CREDIT,
							SUM(A.TOTAL_AMOUNT_IN *-1) AS FINAL
					   FROM VW_STOCK_IN A,
							VENDOR B
					  WHERE A.VENDOR_ID = B.ID
						AND  CASE
							   WHEN P_ENTRY_DATE_FROM <> "" THEN A.SN_ENTRY_DATE < P_ENTRY_DATE_FROM
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_VENDOR_ID <> "" THEN B.ID = P_VENDOR_ID
							   ELSE TRUE
							END
						AND CASE
							   WHEN P_COMPANY_ID <> "" THEN A.COMPANY_ID = P_COMPANY_ID
							   ELSE TRUE
							END
				   GROUP BY B.VENDOR_ID, A.SN_ENTRY_DATE, A.SN_ID
				   ) C
			 WHERE CASE
					  WHEN P_FORM_TYPE <> "-1" THEN FLAG IN (P_FORM_TYPE)
					  ELSE TRUE
				   END
		   ) Z
  GROUP BY VENDOR_ID;
     
	-- =========== Beginning Balance ===========
	
	SET @QRY = CONCAT('SELECT FORM_ID,
							  CASE
								 WHEN FORM IS NOT NULL THEN VENDOR_ID
								 ELSE NULL
							  END AS Vendor,
							  ENTRY_DATE,
							  PAYPAL_TRANSACTION_ID,
							  FORM,
								  Round(cast(SUM(DEBIT) as Decimal(22,2)),2)
							  AS DEBIT,
								  Round(cast(SUM(CREDIT) as Decimal(22,2)),2)
							  AS CREDIT,
							  Round(cast(SUM(FINAL)as Decimal(22,2)),2) AS BALANCE,
                              ',BEGININGBALANCE,' as BEG_BAL,
							  COUNT(*) OVER() AS TOTAL_ROWS
					     FROM (
                      SELECT 		   FORM_ID,
									   VENDOR_ID,
									   ENTRY_DATE,
									   PAYPAL_TRANSACTION_ID,
                                       FLAG,
									   FORM,
									   DEBIT,
									   CREDIT,
									   FINAL
								  FROM ( SELECT id as FORM_ID,
												VENDOR_ID, 
											    "" AS ENTRY_DATE, 
											    "" AS PAYPAL_TRANSACTION_ID, 
											    ''X'' AS FLAG, 
											    ''Beginning Balance'' AS FORM,
											    NULL AS DEBIT,
											    NULL AS CREDIT,
											    (SUM(TOTAL_AMOUNT) + IFNULL((\'',BEGININGBALANCE,'\'), 0)) AS FINAL
										   FROM VENDOR 
										  WHERE CASE
												   WHEN \'',P_VENDOR_ID,'\' <> "" THEN ID = \'',P_VENDOR_ID,'\'
												   ELSE TRUE
											    END
									   GROUP BY VENDOR_ID, ENTRY_DATE,id
											 
									     UNION ALL 
                                  
                                         SELECT A.ID as FORM_ID,
												B.VENDOR_ID, 
											    A.VCM_ENTRY_DATE AS ENTRY_DATE, 
											    A.PAYPAL_TRANSACTION_ID, 
											    ''V'' AS FLAG, 
											    ''Vendor Credit Memo'' AS FORM,
											    SUM(A.VCM_TOTAL) AS DEBIT,
											    NULL AS CREDIT,
											    SUM(A.VCM_TOTAL) AS FINAL
										   FROM VENDOR_CREDIT_MEMO A,
											    VENDOR B
										  WHERE A.VENDOR_ID = B.ID
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_FROM,'\' <> "" THEN A.VCM_ENTRY_DATE >= \'',P_ENTRY_DATE_FROM,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_TO,'\' <> "" THEN A.VCM_ENTRY_DATE <= \'',P_ENTRY_DATE_TO,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_VENDOR_ID,'\' <> "" THEN B.ID = \'',P_VENDOR_ID,'\'
												   ELSE TRUE
											    END
											AND CASE
												   WHEN \'',P_COMPANY_ID,'\' <> "" THEN A.COMPANY_ID = \'',P_COMPANY_ID,'\'
												   ELSE TRUE
											    END
									   GROUP BY B.VENDOR_ID, A.VCM_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID,A.id
											 
									     UNION ALL 
									   
									     SELECT A.ID as FORM_ID,
												B.VENDOR_ID, 
											    A.RECEIVE_ENTRY_DATE AS ENTRY_DATE, 
											    A.PAYPAL_TRANSACTION_ID AS PAYPAL_TRANSACTION_ID, 
											    ''R'' AS FLAG, 
											    ''Receive Order'' AS FORM,
												NULL AS DEBIT,
											    SUM(A.RECEIVE_TOTAL_AMOUNT) AS CREDIT,
											    SUM(A.RECEIVE_TOTAL_AMOUNT * -1) AS FINAL
										   FROM RECEIVE_ORDER A,
											    VENDOR B
										  WHERE A.VENDOR_ID = B.ID
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_FROM,'\' <> "" THEN A.RECEIVE_ENTRY_DATE >= \'',P_ENTRY_DATE_FROM,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_TO,'\' <> "" THEN A.RECEIVE_ENTRY_DATE <= \'',P_ENTRY_DATE_TO,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_VENDOR_ID,'\' <> "" THEN B.ID = \'',P_VENDOR_ID,'\'
												   ELSE TRUE
											    END
											AND CASE
												   WHEN \'',P_COMPANY_ID,'\' <> "" THEN A.COMPANY_ID = \'',P_COMPANY_ID,'\'
												   ELSE TRUE
											    END
									   GROUP BY B.VENDOR_ID, A.RECEIVE_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID,A.id
											  
									     UNION ALL
										
									     SELECT A.ID as FORM_ID,
												B.VENDOR_ID, 
											    A.PS_ENTRY_DATE AS ENTRY_DATE, 
											    A.PAYPAL_TRANSACTION_ID, 
											    ''P'' AS FLAG,
											    ''Payment Sent'' AS FORM,
											    SUM(A.AMOUNT) AS DEBIT,
											    NULL AS CREDIT,
											    SUM(A.AMOUNT) AS FINAL
										   FROM PAYMENT_SENT A,
										  	    VENDOR B
										  WHERE A.VENDOR_ID = B.ID
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_FROM,'\' <> "" THEN A.PS_ENTRY_DATE >= \'',P_ENTRY_DATE_FROM,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_TO,'\' <> "" THEN A.PS_ENTRY_DATE <= \'',P_ENTRY_DATE_TO,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_VENDOR_ID,'\' <> "" THEN B.ID = \'',P_VENDOR_ID,'\'
												   ELSE TRUE
											    END
											AND CASE
												   WHEN \'',P_COMPANY_ID,'\' <> "" THEN A.COMPANY_ID = \'',P_COMPANY_ID,'\'
												   ELSE TRUE
											    END
									   GROUP BY B.VENDOR_ID, A.PS_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID,A.id
											  
									     UNION ALL 
										
									     SELECT A.ID as FORM_ID,
												B.VENDOR_ID, 
											    A.PC_ENTRY_DATE AS ENTRY_DATE, 
											    A.PAYPAL_TRANSACTION_ID, 
											    ''C'' AS FLAG, 
											    ''Partial Credit'' AS FORM,
												SUM(A.TOTAL_AMOUNT) AS DEBIT,
											    NULL AS CREDIT,
											    SUM(A.TOTAL_AMOUNT * -1) AS FINAL
										   FROM PARTIAL_CREDIT A,
											    VENDOR B
										  WHERE A.VENDOR_ID = B.ID
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_FROM,'\' <> "" THEN A.PC_ENTRY_DATE >= \'',P_ENTRY_DATE_FROM,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_TO,'\' <> "" THEN A.PC_ENTRY_DATE <= \'',P_ENTRY_DATE_TO,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_VENDOR_ID,'\' <> "" THEN B.ID = \'',P_VENDOR_ID,'\'
												   ELSE TRUE
											    END
											AND CASE
												   WHEN \'',P_COMPANY_ID,'\' <> "" THEN A.COMPANY_ID = \'',P_COMPANY_ID,'\'
												   ELSE TRUE
											    END
									   GROUP BY B.VENDOR_ID, A.PC_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID,A.id
                                       
									     UNION ALL

									     SELECT A.ID as FORM_ID,
												B.VENDOR_ID, 
											    A.RM_ENTRY_DATE AS ENTRY_DATE, 
											    A.PAYPAL_TRANSACTION_ID, 
											    ''M'' AS FLAG, 
											    ''Receive Money'' AS FORM,
											    NULL AS DEBIT,
											    SUM(A.AMOUNT ) AS CREDIT,
											    SUM(A.AMOUNT * -1) AS FINAL
										   FROM RECEIVE_MONEY A,
											    VENDOR B
										  WHERE A.VENDOR_ID = B.ID
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_FROM,'\' <> "" THEN A.RM_ENTRY_DATE >= \'',P_ENTRY_DATE_FROM,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_TO,'\' <> "" THEN A.RM_ENTRY_DATE <= \'',P_ENTRY_DATE_TO,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_VENDOR_ID,'\' <> "" THEN B.ID = \'',P_VENDOR_ID,'\'
												   ELSE TRUE
											    END
											AND CASE
												   WHEN \'',P_COMPANY_ID,'\' <> "" THEN A.COMPANY_ID = \'',P_COMPANY_ID,'\'
												   ELSE TRUE
											    END
									   GROUP BY B.VENDOR_ID, A.RM_ENTRY_DATE, A.PAYPAL_TRANSACTION_ID,A.id
                                       
                                         UNION ALL
                                       
                                         SELECT A.ID as FORM_ID,
												B.VENDOR_ID, 
											    A.PAY_ENTRY_DATE AS ENTRY_DATE, 
											    A.PAY_REFERENCE AS PAYPAL_TRANSACTION_ID, 
											    ''O'' AS FLAG, 
											    ''Vendor Payment'' AS FORM,
												CASE 
													WHEN A.REMAINING_AMOUNT > 0 THEN SUM(ABS(A.REMAINING_AMOUNT)) 
													ELSE NULL 
                                                END AS DEBIT,
												CASE 
													WHEN A.REMAINING_AMOUNT < 0 THEN SUM(ABS(A.REMAINING_AMOUNT)) 
													ELSE NULL  
                                                END AS CREDIT,
												CASE 
													WHEN A.REMAINING_AMOUNT > 0 THEN SUM(ABS(A.REMAINING_AMOUNT)) 
													ELSE SUM(ABS(A.REMAINING_AMOUNT) * -1)
                                                END AS FINAL
										   FROM PAYMENTS A,
											    VENDOR B
										  WHERE A.VENDOR_ID = B.ID
                                            AND A.REMAINING_AMOUNT <> 0
										    AND CASE 
												   WHEN \'',P_ENTRY_DATE_FROM,'\' <> "" THEN A.PAY_ENTRY_DATE >= \'',P_ENTRY_DATE_FROM,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_TO,'\' <> "" THEN A.PAY_ENTRY_DATE <= \'',P_ENTRY_DATE_TO,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_VENDOR_ID,'\' <> "" THEN B.ID = \'',P_VENDOR_ID,'\'
												   ELSE TRUE
											    END
											AND CASE
												   WHEN \'',P_COMPANY_ID,'\' <> "" THEN A.COMPANY_ID = \'',P_COMPANY_ID,'\'
												   ELSE TRUE
											    END
									   GROUP BY B.VENDOR_ID, A.PAY_ENTRY_DATE, A.PAY_REFERENCE,A.id
                                       
                                         UNION ALL 
									   
									     SELECT A.ID as FORM_ID,
												B.VENDOR_ID, 
											    A.SN_ENTRY_DATE AS ENTRY_DATE, 
											    A.SN_ID AS PAYPAL_TRANSACTION_ID, 
											    ''N'' AS FLAG, 
											    ''Stock In'' AS FORM,
												NULL AS DEBIT,
											    SUM(A.TOTAL_AMOUNT_IN ) AS CREDIT,
											    SUM(A.TOTAL_AMOUNT_IN *-1) AS FINAL
										   FROM VW_STOCK_IN A,
											    VENDOR B
										  WHERE A.VENDOR_ID = B.ID
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_FROM,'\' <> "" THEN A.SN_ENTRY_DATE >= \'',P_ENTRY_DATE_FROM,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_ENTRY_DATE_TO,'\' <> "" THEN A.SN_ENTRY_DATE <= \'',P_ENTRY_DATE_TO,'\'
												   ELSE TRUE
											    END
										    AND CASE
												   WHEN \'',P_VENDOR_ID,'\' <> "" THEN B.ID = \'',P_VENDOR_ID,'\'
												   ELSE TRUE
											    END
											AND CASE
												   WHEN \'',P_COMPANY_ID,'\' <> "" THEN A.COMPANY_ID = \'',P_COMPANY_ID,'\'
												   ELSE TRUE
											    END
									   GROUP BY B.VENDOR_ID, A.SN_ENTRY_DATE, A.SN_ID,A.id
									   ) C
							     WHERE CASE
										  WHEN \'',P_FORM_TYPE,'\' <> "-1" THEN FLAG IN (',P_FORM_TYPE,')
										  ELSE TRUE
									   END
                                       ) Z
				       GROUP BY 	   FORM_ID,
									   VENDOR_ID,
									   ENTRY_DATE,
									   PAYPAL_TRANSACTION_ID,
                                       FLAG,
									   FORM  WITH ROLLUP
                                       having Form_Id is null or FORM is not null LIMIT ',P_START,', ',P_LENGTH,';');
                        
    

    
    PREPARE STMP FROM @QRY;
    EXECUTE STMP ;
    DEALLOCATE PREPARE STMP;


END $$
DELIMITER ;
